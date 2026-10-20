/** Reuses Salesforce object and field details during one transaction. */
public with sharing class PromptContextSchemaCache {
  private static Map<String, Schema.SObjectType> globalByName;
  private static Map<Schema.SObjectType, Schema.DescribeSObjectResult> objectsByType;
  private static Map<Schema.SObjectField, Schema.DescribeFieldResult> fieldsByToken;
  private static Map<Schema.SObjectType, Map<String, Schema.SObjectField>> relationshipsByType;

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

  /** Returns an object's lookup fields keyed by lowercase relationship name, built once per object. */
  public static Map<String, Schema.SObjectField> relationshipFields(
    Schema.DescribeSObjectResult objectDescription
  ) {
    if (relationshipsByType == null) {
      relationshipsByType = new Map<Schema.SObjectType, Map<String, Schema.SObjectField>>();
    }
    Schema.SObjectType objectType = objectDescription.getSObjectType();
    if (!relationshipsByType.containsKey(objectType)) {
      Map<String, Schema.SObjectField> byName = new Map<String, Schema.SObjectField>();
      for (
        Schema.SObjectField fieldToken : objectDescription.fields.getMap()
          .values()
      ) {
        Schema.DescribeFieldResult fieldDescription = describeField(fieldToken);
        if (
          fieldDescription.getType() == Schema.DisplayType.Reference &&
          fieldDescription.getRelationshipName() != null
        ) {
          byName.put(
            fieldDescription.getRelationshipName().toLowerCase(),
            fieldToken
          );
        }
      }
      relationshipsByType.put(objectType, byName);
    }
    return relationshipsByType.get(objectType);
  }

  @TestVisible
  private static void clearForTest() {
    globalByName = null;
    objectsByType = null;
    fieldsByToken = null;
    relationshipsByType = null;
  }
}
