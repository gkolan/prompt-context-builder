/**
 * Lists the Salesforce objects and fields available to Prompt Context Builder.
 */
public with sharing class PromptContextSchema {
  private static final Set<Schema.DisplayType> BLOCKED_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Base64,
    Schema.DisplayType.EncryptedString
  };
  private static final Integer MAX_PICKLIST_CHOICES = 500;
  /** Compound fields are not offered for new templates; choose their individual parts. */
  private static final Set<Schema.DisplayType> COMPOUND_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Address,
    Schema.DisplayType.Location
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
    Boolean supportedCustomRecord = apiName.endsWith('__c');
    Boolean implementationDetail =
      apiName.endsWith('Feed') ||
      apiName.endsWith('History') ||
      apiName.endsWith('Share') ||
      apiName.endsWith('ChangeEvent') ||
      apiName.endsWith('__b') ||
      apiName.endsWith('__kav') ||
      apiName.endsWith('__x');
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
      if (
        isReadableSupported(fieldDescription) &&
        !COMPOUND_TYPES.contains(fieldDescription.getType())
      ) {
        PromptContextDTO.Option option = new PromptContextDTO.Option(
          fieldDescription.getLabel() + ' (' + fieldDescription.getName() + ')',
          fieldDescription.getName(),
          String.valueOf(fieldDescription.getType())
        );
        option.picklistValues = picklistChoices(fieldDescription);
        options.add(option);
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
  private static List<PromptContextDTO.Option> picklistChoices(
    Schema.DescribeFieldResult fieldDescription
  ) {
    if (
      fieldDescription.getType() != Schema.DisplayType.Picklist &&
      fieldDescription.getType() != Schema.DisplayType.MultiPicklist
    ) {
      return null;
    }
    List<PromptContextDTO.Option> choices = new List<PromptContextDTO.Option>();
    for (Schema.PicklistEntry entry : fieldDescription.getPicklistValues()) {
      if (entry.isActive() && choices.size() < MAX_PICKLIST_CHOICES) {
        choices.add(
          new PromptContextDTO.Option(entry.getLabel(), entry.getValue(), null)
        );
      }
    }
    return choices;
  }

  /**
   * Adds the record currency code beside every currency field path in a multi-currency org, so
   * syntax version 2 can print each amount with its own currency.
   * @param objectApiName Object that owns the paths
   * @param fieldPaths Requested field paths; unchanged when the org has one currency
   * @return The same set, with sibling CurrencyIsoCode paths added
   */
  public static Set<String> addCurrencyCodePaths(
    String objectApiName,
    Set<String> fieldPaths
  ) {
    if (!UserInfo.isMultiCurrencyOrganization()) {
      return fieldPaths;
    }
    for (String fieldPath : new List<String>(fieldPaths)) {
      Schema.DescribeFieldResult description;
      try {
        description = getTerminalFieldDescription(objectApiName, fieldPath);
      } catch (Exception exceptionValue) {
        // Unreadable paths fail later with their own access reason.
        continue;
      }
      if (description?.getType() == Schema.DisplayType.Currency) {
        Integer lastDot = fieldPath.lastIndexOf('.');
        fieldPaths.add(
          (lastDot < 0 ? '' : fieldPath.substring(0, lastDot + 1)) +
          'CurrencyIsoCode'
        );
      }
    }
    return fieldPaths;
  }

  /**
   * Returns the API name of the object that owns the last field in a path.
   * @param objectApiName Starting object
   * @param requestedPath Field path
   * @return Owning object API name
   */
  public static String terminalObjectName(
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
      currentObject = PromptContextSchemaCache.describeObject(
        PromptContextSchemaCache.describeField(
            findRelationshipField(currentObject, segments[index])
          )
          .getReferenceTo()[0]
      );
    }
    return currentObject.getName();
  }

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
