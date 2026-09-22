/** Reuses Salesforce object and field details during one transaction. */
public with sharing class PromptContextSchemaCache {
  private static Map<String, Schema.SObjectType> globalByName;
  private static Map<Schema.SObjectType, Schema.DescribeSObjectResult> objectsByType;
  private static Map<Schema.SObjectField, Schema.DescribeFieldResult> fieldsByToken;

  public static Map<String, Schema.SObjectType> globalDescribe() {
    if (globalByName == null) {
      globalByName = Schema.getGlobalDescribe();
    }
    return globalByName;
  }

  public static Schema.SObjectType objectType(String objectApiName) {
    return String.isBlank(objectApiName)
      ? null
      : globalDescribe().get(objectApiName);
  }

  public static Schema.DescribeSObjectResult describeObject(
    Schema.SObjectType objectType
  ) {
    if (objectType == null) {
      return null;
    }
    if (objectsByType == null) {
      objectsByType = new Map<Schema.SObjectType, Schema.DescribeSObjectResult>();
    }
    if (!objectsByType.containsKey(objectType)) {
      objectsByType.put(
        objectType,
        objectType.getDescribe(SObjectDescribeOptions.DEFERRED)
      );
    }
    return objectsByType.get(objectType);
  }

  public static Schema.DescribeFieldResult describeField(
    Schema.SObjectField fieldToken
  ) {
    if (fieldToken == null) {
      return null;
    }
    if (fieldsByToken == null) {
      fieldsByToken = new Map<Schema.SObjectField, Schema.DescribeFieldResult>();
    }
    if (!fieldsByToken.containsKey(fieldToken)) {
      fieldsByToken.put(fieldToken, fieldToken.getDescribe());
    }
    return fieldsByToken.get(fieldToken);
  }

  @TestVisible
  private static void clearForTest() {
    globalByName = null;
    objectsByType = null;
    fieldsByToken = null;
  }
}
