/** Stable bulk-first API shared by Apex, Flow, Queueable, Batch, and Scheduled execution. */
global with sharing class PromptContextApi {
  global class Request {
    @AuraEnabled
    @InvocableVariable(label='Published Template Id')
    global Id templateId;
    @AuraEnabled
    @InvocableVariable(label='Template Automation Key')
    global String templateDeveloperKey;
    @AuraEnabled
    @InvocableVariable(required=true label='Record Id')
    global Id recordId;
  }

  global class Response {
    @AuraEnabled
    @InvocableVariable
    global Id templateId;
    @AuraEnabled
    @InvocableVariable
    global Id recordId;
    @AuraEnabled
    @InvocableVariable
    global Boolean success;
    @AuraEnabled
    @InvocableVariable
    global String reasonCode;
    @AuraEnabled
    @InvocableVariable
    global String message;
    @AuraEnabled
    @InvocableVariable
    global String warningCodes;
    @AuraEnabled
    @InvocableVariable
    global String warningMessage;
    @AuraEnabled
    @InvocableVariable
    global String prompt;
    @AuraEnabled
    @InvocableVariable
    global Integer templateVersion;
    @AuraEnabled
    @InvocableVariable
    global String contractVersion;
    @AuraEnabled
    @InvocableVariable
    global Integer syntaxVersion;
    @AuraEnabled
    @InvocableVariable
    global String correlationId;
    @AuraEnabled
    @InvocableVariable
    global String diagnosticSummary;
  }

  @InvocableMethod(
    label='Build Record Context Prompt'
    description='Builds one prompt per record using a published template and user-mode record access.'
  )
  global static List<Response> buildForFlow(List<Request> requests) {
    return buildInternal(requests, 'FLOW');
  }

  global static List<Response> build(List<Request> requests) {
    return buildInternal(requests, 'APEX');
  }

  private static List<Response> buildInternal(
    List<Request> requests,
    String channel
  ) {
    Long startedAtMilliseconds = Datetime.now().getTime();
    PromptContextAccess.requireGenerate();
    List<Request> safeRequests = requests ?? new List<Request>();
    if (safeRequests.size() > PromptContextContract.MAX_RECORDS_PER_REQUEST) {
      throw new PromptContextException(
        'A request can contain at most ' +
          PromptContextContract.MAX_RECORDS_PER_REQUEST +
          ' records.'
      );
    }
    Map<Id, List<Integer>> indexesByTemplate = new Map<Id, List<Integer>>();
    List<Response> responses = new List<Response>();
    Set<String> requestedDeveloperKeys = new Set<String>();
    for (Request request : safeRequests) {
      if (
        request != null &&
        request.templateId == null &&
        !String.isBlank(request.templateDeveloperKey)
      ) {
        requestedDeveloperKeys.add(request.templateDeveloperKey.trim());
      }
    }
    Map<String, Prompt_Template__c> templatesByKey = PromptContextSelector.selectTemplatesByDeveloperKeys(
      requestedDeveloperKeys
    );
    for (Integer index = 0; index < safeRequests.size(); index++) {
      Request request = safeRequests[index];
      Response response = baseResponse(request);
      responses.add(response);
      Id effectiveTemplateId = request?.templateId;
      if (
        effectiveTemplateId == null &&
        !String.isBlank(request?.templateDeveloperKey)
      ) {
        Prompt_Template__c resolvedTemplate = templatesByKey.get(
          request.templateDeveloperKey.trim().toLowerCase()
        );
        effectiveTemplateId = resolvedTemplate?.Id;
      }
      response.templateId = effectiveTemplateId;
      if (
        request == null ||
        effectiveTemplateId == null ||
        request.recordId == null
      ) {
        fail(
          response,
          PromptContextReasonCodes.INVALID_REQUEST,
          'A valid Template Id or Template Automation Key and a Record Id are required.'
        );
      } else {
        if (!indexesByTemplate.containsKey(effectiveTemplateId)) {
          indexesByTemplate.put(effectiveTemplateId, new List<Integer>());
        }
        indexesByTemplate.get(effectiveTemplateId).add(index);
      }
    }
    if (indexesByTemplate.size() > PromptContextContract.MAX_FLOW_GROUPS) {
      for (Response response : responses) {
        if (response.reasonCode == null) {
          fail(
            response,
            PromptContextReasonCodes.FLOW_GROUP_LIMIT_EXCEEDED,
            'Use no more than ' +
              PromptContextContract.MAX_FLOW_GROUPS +
              ' templates in one transaction.'
          );
        }
      }
      publishMetrics(channel, responses, startedAtMilliseconds);
      return responses;
    }
    for (Id templateId : indexesByTemplate.keySet()) {
      executeGroup(
        templateId,
        indexesByTemplate.get(templateId),
        safeRequests,
        responses
      );
    }
    enforceFlowPayloadLimit(responses);
    publishMetrics(channel, responses, startedAtMilliseconds);
    return responses;
  }

  private static void publishMetrics(
    String channel,
    List<Response> responses,
    Long startedAtMilliseconds
  ) {
    List<PromptContextMetrics.Signal> signals = new List<PromptContextMetrics.Signal>();
    for (Response response : responses) {
      if (response.templateId == null || String.isBlank(response.reasonCode)) {
        continue;
      }
      PromptContextMetrics.Signal signal = new PromptContextMetrics.Signal();
      signal.channel = channel;
      signal.outcomeCode = response.reasonCode;
      signal.startedAtMilliseconds = startedAtMilliseconds;
      signal.templateId = response.templateId;
      signal.templateVersion = response.templateVersion;
      signal.correlationId = response.correlationId;
      signals.add(signal);
    }
    PromptContextMetrics.publishAll(signals);
  }

  private static void executeGroup(
    Id templateId,
    List<Integer> indexes,
    List<Request> requests,
    List<Response> responses
  ) {
    try {
      PromptContextDTO.TemplateConfig header = PromptTemplateService.getTemplate(
        templateId
      );
      if (header.status != 'Published') {
        throw new PromptContextException(
          'Only a published template can generate prompts.'
        );
      }
      PromptContextDTO.TemplateConfig config = PromptTemplateService.getPublishedConfig(
        header
      );
      PromptContextResourcePlanner.Plan plan = PromptContextResourcePlanner.plan(
        config
      );
      for (Integer position = 0; position < indexes.size(); position++) {
        Integer responseIndex = indexes[position];
        Response response = responses[responseIndex];
        if (position >= plan.safeRecordCount) {
          fail(
            response,
            PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED,
            'This Salesforce transaction cannot safely read more records. Reduce the Flow collection or use Batch Apex.'
          );
          continue;
        }
        try {
          PromptContextDTO.PromptResult result = PromptContextService.generate(
            config,
            requests[responseIndex].recordId
          );
          response.success = true;
          response.reasonCode = PromptContextReasonCodes.SUCCESS;
          response.message = 'Prompt built successfully.';
          copyWarnings(result.messages, response);
          response.prompt = result.prompt;
          response.templateVersion = result.templateVersion;
          response.contractVersion = result.contractVersion;
          response.syntaxVersion = result.syntaxVersion;
          response.diagnosticSummary = PromptContextTrace.diagnosticSummary(
            PromptContextReasonCodes.SUCCESS,
            result.templateVersion
          );
        } catch (Exception itemException) {
          fail(
            response,
            classify(itemException),
            PromptContextTrace.safeMessage(itemException)
          );
        }
      }
    } catch (Exception groupException) {
      for (Integer responseIndex : indexes) {
        fail(
          responses[responseIndex],
          classify(groupException),
          PromptContextTrace.safeMessage(groupException)
        );
      }
    }
  }

  private static Response baseResponse(Request request) {
    Response response = new Response();
    response.templateId = request?.templateId;
    response.recordId = request?.recordId;
    response.success = false;
    response.correlationId = PromptContextTrace.newCorrelationId();
    return response;
  }

  private static void copyWarnings(
    List<PromptContextDTO.Message> messages,
    Response response
  ) {
    List<String> codes = new List<String>();
    List<String> explanations = new List<String>();
    for (PromptContextDTO.Message resultMessage : messages) {
      if (resultMessage.severity != 'WARNING') {
        continue;
      }
      codes.add(resultMessage.code);
      explanations.add(resultMessage.text);
    }
    response.warningCodes = String.join(codes, ',');
    response.warningMessage = String.join(explanations, ' ');
  }

  private static void enforceFlowPayloadLimit(List<Response> responses) {
    Integer characterCount = 0;
    for (Response response : responses) {
      if (!response.success || response.prompt == null) {
        continue;
      }
      characterCount += response.prompt.length();
      if (characterCount > PromptContextContract.MAX_FLOW_RESPONSE_CHARACTERS) {
        fail(
          response,
          PromptContextReasonCodes.FLOW_PAYLOAD_LIMIT_EXCEEDED,
          'The Flow response collection is too large. Reduce the record collection or use Batch Apex.'
        );
      }
    }
  }

  private static void fail(
    Response response,
    String reasonCode,
    String message
  ) {
    response.success = false;
    response.reasonCode = reasonCode;
    response.message = message;
    response.warningCodes = null;
    response.warningMessage = null;
    response.prompt = null;
    response.diagnosticSummary = PromptContextTrace.diagnosticSummary(
      reasonCode,
      response.templateVersion
    );
  }

  private static String classify(Exception exceptionValue) {
    if (exceptionValue instanceof PromptContextAccess.AuthorizationException) {
      return PromptContextReasonCodes.NOT_AUTHORIZED;
    }
    if (exceptionValue instanceof PromptContextException) {
      String domainReason = ((PromptContextException) exceptionValue)
        .reasonCode;
      if (!String.isBlank(domainReason)) {
        return domainReason;
      }
    }
    String message = exceptionValue.getMessage()?.toLowerCase();
    if (
      message != null &&
      message.contains('record') &&
      (message.contains('not found') || message.contains('not accessible'))
    ) {
      return PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE;
    }
    if (
      message != null &&
      message.contains('prompt') &&
      message.contains('long')
    ) {
      return PromptContextReasonCodes.PROMPT_TOO_LONG;
    }
    if (
      message != null &&
      (message.contains('invalid configuration') ||
      message.contains('configuration contains') ||
      message.contains('template contains'))
    ) {
      return PromptContextReasonCodes.INVALID_CONFIGURATION;
    }
    if (message != null && message.contains('not found')) {
      return PromptContextReasonCodes.TEMPLATE_NOT_FOUND;
    }
    if (message != null && message.contains('published')) {
      return PromptContextReasonCodes.TEMPLATE_NOT_PUBLISHED;
    }
    return PromptContextReasonCodes.UNEXPECTED_ERROR;
  }
}
