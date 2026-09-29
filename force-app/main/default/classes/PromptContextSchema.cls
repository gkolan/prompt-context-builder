/**
 * Lists the Salesforce objects and fields available to Prompt Context Builder.
 */
public with sharing class PromptContextSchema {
  private static final Set<Schema.DisplayType> BLOCKED_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Base64,
    Schema.DisplayType.EncryptedString
  };

  /**
   * Returns accessible, queryable objects sorted by label.
   * @return Object choices available to the current user
   */
  public static List<PromptContextDTO.Option> getObjectOptions() {
    List<PromptContextDTO.Option> options = new List<PromptContextDTO.Option>();
    for (
      Schema.SObjectType objectType : PromptContextSchemaCache.globalDescribe()
        .values()
    ) {
      Schema.DescribeSObjectResult description = PromptContextSchemaCache.describeObject(
        objectType
      );
      String objectLabel = description.getLabel();
      if (
        description.isAccessible() &&
        description.isQueryable() &&
        isBusinessObjectForPicker(description) &&
        !description.isCustomSetting() &&
        !String.isBlank(objectLabel) &&
        !objectLabel.startsWith('__MISSING LABEL__') &&
        !description.isDeprecatedAndHidden()
      ) {
        options.add(
          new PromptContextDTO.Option(
            objectLabel + ' (' + description.getName() + ')',
            description.getName(),
            null
          )
        );
      }
    }
    options.sort();
    return options;
  }

  private static Boolean isBusinessObjectForPicker(
    Schema.DescribeSObjectResult description
  ) {
    String apiName = description.getName();
    Boolean editableRecord =
      description.isCreateable() || description.isUpdateable();
    Boolean supportedCustomRecord =
      apiName.endsWith('__c') || apiName.endsWith('__x');
    Boolean implementationDetail =
      apiName.endsWith('Feed') ||
      apiName.endsWith('History') ||
      apiName.endsWith('Share') ||
      apiName.endsWith('ChangeEvent');
    return (editableRecord || supportedCustomRecord) && !implementationDetail;
  }

  /**
   * Returns readable, supported direct fields for an object.
   * @param objectApiName Object API name
   * @return Field choices sorted by label
   * @throws PromptContextException when the object is unavailable
   */
  public static List<PromptContextDTO.Option> getFieldOptions(
    String objectApiName
  ) {
    Schema.DescribeSObjectResult objectDescription = requireReadableObject(
      objectApiName
    );
    List<PromptContextDTO.Option> options = new List<PromptContextDTO.Option>();
    for (
      Schema.SObjectField fieldToken : objectDescription.fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult fieldDescription = PromptContextSchemaCache.describeField(
        fieldToken
      );
      if (isReadableSupported(fieldDescription)) {
        options.add(
          new PromptContextDTO.Option(
            fieldDescription.getLabel() +
              ' (' +
              fieldDescription.getName() +
              ')',
            fieldDescription.getName(),
            String.valueOf(fieldDescription.getType())
          )
        );
      }
    }
    options.sort();
    return options;
  }

  /**
   * Requires an accessible and queryable object.
   * @param objectApiName Object API name
   * @return Validated object description
   * @throws PromptContextException when the object is missing or inaccessible
   */
  public static Schema.DescribeSObjectResult requireReadableObject(
    String objectApiName
  ) {
    Schema.SObjectType objectType = PromptContextSchemaCache.objectType(
      objectApiName
    );
    if (objectType == null) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Salesforce object ' + objectApiName + ' was not found.'
      );
    }
    Schema.DescribeSObjectResult description = PromptContextSchemaCache.describeObject(
      objectType
    );
    if (!description.isAccessible() || !description.isQueryable()) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.OBJECT_NOT_ACCESSIBLE,
        'You do not have access to Salesforce object ' + objectApiName + '.'
      );
    }
    return description;
  }

  /**
   * Validates a readable field or parent relationship path and returns its canonical SOQL path.
   * @param objectApiName Starting object API name
   * @param requestedPath Field path supplied by configuration or merge syntax
   * @return Canonical field path
   * @throws PromptContextException when any segment is invalid or inaccessible
   */
  public static String requireReadableFieldPath(
    String objectApiName,
    String requestedPath
  ) {
    if (String.isBlank(requestedPath)) {
      throw new PromptContextException('A field name is required.');
    }
    List<String> segments = requestedPath.trim().split('\\.');
    if (segments.size() > PromptContextContract.MAX_RELATIONSHIP_DEPTH + 1) {
      throw new PromptContextException(
        'Field path ' + requestedPath + ' is deeper than five relationships.'
      );
    }

    Schema.DescribeSObjectResult currentObject = requireReadableObject(
      objectApiName
    );
    List<String> canonicalSegments = new List<String>();
    for (Integer index = 0; index < segments.size(); index++) {
      String segment = segments[index];
      Boolean isLast = index == segments.size() - 1;
      if (isLast) {
        Schema.SObjectField fieldToken = findField(currentObject, segment);
        Schema.DescribeFieldResult fieldDescription = PromptContextSchemaCache.describeField(
          fieldToken
        );
        if (fieldToken == null) {
          throw PromptContextException.withReason(
            PromptContextReasonCodes.INVALID_CONFIGURATION,
            'Field ' + requestedPath + ' does not exist.'
          );
        }
        if (!fieldDescription.isAccessible()) {
          throw PromptContextException.withReason(
            PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
            'Field ' + requestedPath + ' is not readable.'
          );
        }
        if (!isReadableSupported(fieldDescription)) {
          throw PromptContextException.withReason(
            PromptContextReasonCodes.INVALID_CONFIGURATION,
            'Field ' + requestedPath + ' is not readable or supported.'
          );
        }
        canonicalSegments.add(fieldDescription.getName());
        continue;
      }

      Schema.SObjectField relationshipField = findRelationshipField(
        currentObject,
        segment
      );
      Schema.DescribeFieldResult relationshipDescription = PromptContextSchemaCache.describeField(
        relationshipField
      );
      if (
        relationshipField == null || !relationshipDescription.isAccessible()
      ) {
        throw PromptContextException.withReason(
          relationshipField == null
            ? PromptContextReasonCodes.INVALID_CONFIGURATION
            : PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
          'Relationship ' +
            segment +
            ' in ' +
            requestedPath +
            ' is not readable.'
        );
      }
      List<Schema.SObjectType> referenceTypes = relationshipDescription.getReferenceTo();
      if (referenceTypes.size() != 1) {
        throw PromptContextException.withReason(
          PromptContextReasonCodes.INVALID_CONFIGURATION,
          'Relationship ' + segment + ' must reference one object type.'
        );
      }
      canonicalSegments.add(relationshipDescription.getRelationshipName());
      currentObject = PromptContextSchemaCache.describeObject(
        referenceTypes[0]
      );
    }
    return String.join(canonicalSegments, '.');
  }

  /**
   * Returns the description of the terminal field in a validated field path.
   * @param objectApiName Starting object API name
   * @param requestedPath Field path
   * @return Terminal field description
   */
  public static Schema.DescribeFieldResult getTerminalFieldDescription(
    String objectApiName,
    String requestedPath
  ) {
    String canonicalPath = requireReadableFieldPath(
      objectApiName,
      requestedPath
    );
    List<String> segments = canonicalPath.split('\\.');
    Schema.DescribeSObjectResult currentObject = requireReadableObject(
      objectApiName
    );
    for (Integer index = 0; index < segments.size() - 1; index++) {
      Schema.SObjectField relationshipField = findRelationshipField(
        currentObject,
        segments[index]
      );
      currentObject = PromptContextSchemaCache.describeObject(
        PromptContextSchemaCache.describeField(relationshipField)
          .getReferenceTo()[0]
      );
    }
    return PromptContextSchemaCache.describeField(
      findField(currentObject, segments[segments.size() - 1])
    );
  }

  private static Boolean isReadableSupported(
    Schema.DescribeFieldResult description
  ) {
    return description != null &&
      description.isAccessible() &&
      !BLOCKED_TYPES.contains(description.getType());
  }

  private static Schema.SObjectField findField(
    Schema.DescribeSObjectResult objectDescription,
    String requestedName
  ) {
    for (String fieldName : objectDescription.fields.getMap().keySet()) {
      if (fieldName.equalsIgnoreCase(requestedName)) {
        return objectDescription.fields.getMap().get(fieldName);
      }
    }
    return null;
  }

  private static Schema.SObjectField findRelationshipField(
    Schema.DescribeSObjectResult objectDescription,
    String requestedName
  ) {
    for (
      Schema.SObjectField fieldToken : objectDescription.fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult fieldDescription = PromptContextSchemaCache.describeField(
        fieldToken
      );
      if (
        fieldDescription.getType() == Schema.DisplayType.Reference &&
        fieldDescription.getRelationshipName() != null &&
        fieldDescription.getRelationshipName().equalsIgnoreCase(requestedName)
      ) {
        return fieldToken;
      }
    }
    return null;
  }
}
