/**
 * Runs the one prompt-preparation process shared by Apex, Flow, Lightning, Batch, Queueable, and
 * future approved entry points.
 */
public with sharing class PromptContextPreparationService {
  /** Request fields accepted by the common preparation process. */
  public class Request {
    public Id templateId;
    public String templateDeveloperKey;
    public Id recordId;
    public List<Id> selectedContentVersionIds;
  }

  /** Result fields returned by the common preparation process. */
  public class Response {
    public Id templateId;
    public Id templateVersionId;
    public Id recordId;
    public Boolean success;
    public String reasonCode;
    public String message;
    public String warningCodes;
    public String warningMessage;
    public String prompt;
    public String selectedFilesJson;
    public Integer templateVersion;
    public String contractVersion;
    public Integer syntaxVersion;
    public String fingerprint;
    public Map<String, Integer> sourceRecordCounts;
    public List<PromptContextDTO.Message> messages;
    public PromptContextDTO.AccessManifest accessManifest;
    public String correlationId;
    public String diagnosticSummary;
  }

  /**
   * Builds one complete prompt result for each request in the original order.
   * @param requests Published template and current-record selections
   * @param channel Approved entry-point name used only for value-free monitoring
   * @return One ordered result for every request
   */
  public static List<Response> execute(List<Request> requests, String channel) {
    return buildInternal(requests, channel);
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
      if (String.isBlank(response.reasonCode)) {
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
        throw PromptContextException.withReason(
          PromptContextReasonCodes.TEMPLATE_NOT_PUBLISHED,
          'Only a published template can generate prompts.'
        );
      }
      PromptContextDTO.TemplateConfig config = PromptTemplateService.getPublishedConfig(
        header
      );
      PromptContextResourcePlanner.Plan plan = PromptContextResourcePlanner.plan(
        config
      );
      List<Integer> acceptedIndexes = new List<Integer>();
      List<Id> acceptedRecordIds = new List<Id>();
      Map<Integer, PromptContextFilePolicy.Selection> filesByResponseIndex = new Map<Integer, PromptContextFilePolicy.Selection>();
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
          PromptContextFilePolicy.Selection fileSelection = PromptContextFilePolicy.selectFiles(
            config,
            requests[responseIndex].recordId,
            requests[responseIndex].selectedContentVersionIds
          );
          acceptedIndexes.add(responseIndex);
          acceptedRecordIds.add(requests[responseIndex].recordId);
          filesByResponseIndex.put(responseIndex, fileSelection);
        } catch (Exception itemException) {
          fail(
            response,
            classify(itemException),
            PromptContextTrace.safeMessage(itemException)
          );
        }
      }
      List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
        config,
        acceptedRecordIds
      );
      for (
        Integer position = 0; position < acceptedIndexes.size(); position++
      ) {
        Integer responseIndex = acceptedIndexes[position];
        Response response = responses[responseIndex];
        PromptContextBulkService.Outcome outcome = outcomes[position];
        if (!outcome.isSuccess()) {
          fail(response, outcome.reasonCode, outcome.message);
          continue;
        }
        PromptContextDTO.PromptResult result = outcome.result;
        response.success = true;
        response.reasonCode = PromptContextReasonCodes.SUCCESS;
        response.message = 'Prompt built successfully.';
        copyWarnings(result.messages, response);
        response.prompt = result.prompt;
        response.selectedFilesJson = filesByResponseIndex
          .get(responseIndex)
          .selectedFilesJson;
        response.templateVersionId = config.publishedVersionId;
        response.templateVersion = result.templateVersion;
        response.contractVersion = result.contractVersion;
        response.syntaxVersion = result.syntaxVersion;
        response.fingerprint = result.fingerprint;
        response.sourceRecordCounts = result.sourceRecordCounts;
        response.messages = result.messages;
        response.accessManifest = result.accessManifest;
        response.diagnosticSummary = PromptContextTrace.diagnosticSummary(
          PromptContextReasonCodes.SUCCESS,
          result.templateVersion
        );
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
    enforceFlowPayloadLimit(
      responses,
      PromptContextContract.MAX_FLOW_RESPONSE_CHARACTERS
    );
  }

  @TestVisible
  private static void enforceFlowPayloadLimit(
    List<Response> responses,
    Integer maximumCharacters
  ) {
    Integer characterCount = 0;
    for (Response response : responses) {
      if (!response.success || response.prompt == null) {
        continue;
      }
      characterCount += response.prompt.length();
      if (characterCount > maximumCharacters) {
        characterCount -= response.prompt.length();
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
    response.selectedFilesJson = null;
    response.templateVersionId = null;
    response.templateVersion = null;
    response.contractVersion = null;
    response.syntaxVersion = null;
    response.fingerprint = null;
    response.sourceRecordCounts = null;
    response.messages = null;
    response.accessManifest = null;
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
