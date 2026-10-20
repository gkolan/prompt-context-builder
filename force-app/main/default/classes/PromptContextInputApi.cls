/**
 * Provides the one public entry for preparing prompt input for Apex and Flow.
 */
global with sharing class PromptContextInputApi {
  global static final String SAVE_TO_LOG = 'SAVE_TO_LOG';
  global static final String RETURN_TO_APEX = 'RETURN_TO_APEX';

  /** One published-template, current-record, and delivery request. */
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
    @AuraEnabled
    @InvocableVariable(required=true label='Delivery Choice')
    global String deliveryChoice;
    @AuraEnabled
    @InvocableVariable(label='Request Key')
    global String requestKey;
    @AuraEnabled
    @InvocableVariable(label='Selected Salesforce File Version Ids')
    global List<Id> selectedContentVersionIds;
  }

  /** One ordered preparation and delivery result. */
  global class Result {
    @AuraEnabled
    @InvocableVariable
    global Id templateId;
    @AuraEnabled
    @InvocableVariable
    global Id templateVersionId;
    @AuraEnabled
    @InvocableVariable
    global Id recordId;
    @AuraEnabled
    @InvocableVariable
    global Id inputLogId;
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
    global String selectedFilesJson;
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

  private class PreflightFailure {
    public String reasonCode;
    public String message;

    private PreflightFailure(String reasonCode, String message) {
      this.reasonCode = reasonCode;
      this.message = message;
    }
  }

  /**
   * Prepares prompt input for Apex and applies the requested delivery choice.
   * @param requests Published template, current record, and delivery selections
   * @return One ordered result for every request
   */
  global static List<Result> prepare(List<Request> requests) {
    return prepareInternal(requests, 'APEX');
  }

  /**
   * Prepares prompt input for Flow and applies the requested delivery choice.
   * @param requests Published template, current record, and delivery selections
   * @return One ordered result for every request
   */
  @InvocableMethod(
    label='Prepare Record Prompt Input'
    description='Prepares one prompt input per record and either returns it or saves it to a Prompt Input Log.'
  )
  global static List<Result> prepareForFlow(List<Request> requests) {
    return prepareInternal(requests, 'FLOW');
  }

  private static List<Result> prepareInternal(
    List<Request> requests,
    String channel
  ) {
    List<Request> safeRequests = requests ?? new List<Request>();
    List<PromptContextPreparationService.Request> serviceRequests = new List<PromptContextPreparationService.Request>();
    Map<Integer, PreflightFailure> failuresByIndex = new Map<Integer, PreflightFailure>();
    for (Integer index = 0; index < safeRequests.size(); index++) {
      Request request = safeRequests[index];
      PreflightFailure failure = validateDelivery(request);
      if (failure != null) {
        failuresByIndex.put(index, failure);
        serviceRequests.add(null);
      } else {
        serviceRequests.add(mapRequest(request));
      }
    }

    List<Result> results = mapResults(
      PromptContextPreparationService.execute(serviceRequests, channel)
    );
    for (Integer index : failuresByIndex.keySet()) {
      PreflightFailure failure = failuresByIndex.get(index);
      Request request = safeRequests[index];
      results[index].templateId = request?.templateId;
      results[index].recordId = request?.recordId;
      fail(results[index], failure.reasonCode, failure.message);
    }
    saveRequestedInputs(safeRequests, results);
    return results;
  }

  private static PreflightFailure validateDelivery(Request request) {
    if (
      request == null ||
      (request.deliveryChoice != SAVE_TO_LOG &&
      request.deliveryChoice != RETURN_TO_APEX)
    ) {
      return new PreflightFailure(
        PromptContextReasonCodes.INVALID_DELIVERY_CHOICE,
        'Select Save to Prompt Input Log or Return to Apex.'
      );
    }
    if (request.deliveryChoice == SAVE_TO_LOG) {
      if (!PromptContextAccess.canSaveInput()) {
        return new PreflightFailure(
          PromptContextReasonCodes.NOT_AUTHORIZED,
          'You do not have permission to save prepared input.'
        );
      }
      if (String.isBlank(request.requestKey)) {
        return new PreflightFailure(
          PromptContextReasonCodes.REQUEST_KEY_REQUIRED,
          'A Request Key is required when saving prepared input.'
        );
      }
    }
    return null;
  }

  private static PromptContextPreparationService.Request mapRequest(
    Request request
  ) {
    PromptContextPreparationService.Request mapped = new PromptContextPreparationService.Request();
    mapped.templateId = request.templateId;
    mapped.templateDeveloperKey = request.templateDeveloperKey;
    mapped.recordId = request.recordId;
    mapped.selectedContentVersionIds = request.selectedContentVersionIds;
    return mapped;
  }

  private static List<Result> mapResults(
    List<PromptContextPreparationService.Response> serviceResponses
  ) {
    List<Result> results = new List<Result>();
    for (
      PromptContextPreparationService.Response serviceResponse : serviceResponses
    ) {
      Result result = new Result();
      result.templateId = serviceResponse.templateId;
      result.templateVersionId = serviceResponse.templateVersionId;
      result.recordId = serviceResponse.recordId;
      result.success = serviceResponse.success;
      result.reasonCode = serviceResponse.reasonCode;
      result.message = serviceResponse.message;
      result.warningCodes = serviceResponse.warningCodes;
      result.warningMessage = serviceResponse.warningMessage;
      result.prompt = serviceResponse.prompt;
      result.selectedFilesJson = serviceResponse.selectedFilesJson;
      result.templateVersion = serviceResponse.templateVersion;
      result.contractVersion = serviceResponse.contractVersion;
      result.syntaxVersion = serviceResponse.syntaxVersion;
      result.correlationId = serviceResponse.correlationId;
      result.diagnosticSummary = serviceResponse.diagnosticSummary;
      results.add(result);
    }
    return results;
  }

  private static void saveRequestedInputs(
    List<Request> requests,
    List<Result> results
  ) {
    List<PromptContextInputLogService.SaveRequest> saveRequests = new List<PromptContextInputLogService.SaveRequest>();
    for (Integer index = 0; index < requests.size(); index++) {
      Request request = requests[index];
      Result result = results[index];
      if (request?.deliveryChoice != SAVE_TO_LOG || result.success != true) {
        continue;
      }
      PromptContextInputLogService.SaveRequest saveRequest = new PromptContextInputLogService.SaveRequest();
      saveRequest.responseIndex = index;
      saveRequest.requestKey = request.requestKey;
      saveRequest.rootRecordId = result.recordId;
      saveRequest.templateVersionId = result.templateVersionId;
      saveRequest.promptText = result.prompt;
      saveRequest.selectedFilesJson = result.selectedFilesJson;
      saveRequests.add(saveRequest);
    }
    if (saveRequests.isEmpty()) {
      return;
    }
    for (
      PromptContextInputLogService.SaveResult saveResult : PromptContextInputLogService.save(
        saveRequests
      )
    ) {
      Result result = results[saveResult.responseIndex];
      if (saveResult.success) {
        result.inputLogId = saveResult.inputLogId;
        result.message = saveResult.message;
      } else {
        fail(result, saveResult.reasonCode, saveResult.message);
      }
    }
  }

  private static void fail(Result result, String reasonCode, String message) {
    // Read before clearing: support needs the version even though the result no longer returns it.
    result.diagnosticSummary = PromptContextTrace.diagnosticSummary(
      reasonCode,
      result.templateVersion
    );
    result.success = false;
    result.reasonCode = reasonCode;
    result.message = message;
    result.warningCodes = null;
    result.warningMessage = null;
    result.prompt = null;
    result.selectedFilesJson = null;
    result.inputLogId = null;
    result.templateVersionId = null;
    result.templateVersion = null;
    result.contractVersion = null;
    result.syntaxVersion = null;
  }

  private PromptContextInputApi() {
  }
}
