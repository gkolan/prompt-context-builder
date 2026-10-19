/**
 * Requires the running user to read every field a formula field uses, so a formula cannot reveal a
 * value the user's field access hides. Salesforce itself checks only the formula field, so this is
 * deliberately stricter. Formulas whose inputs cannot be identified safely fail closed.
 */
public with sharing class PromptContextFormulaAccess {
  private static final Integer MAX_FORMULA_EXPANSIONS = 10;
  private static final Pattern COMMENT = Pattern.compile('(?s)/\\*.*?\\*/');
  private static final Pattern STRING_LITERAL = Pattern.compile(
    '"(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\''
  );
  private static final Pattern REFERENCE = Pattern.compile(
    '(?<![A-Za-z0-9_$.])([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*)(?![A-Za-z0-9_.]|\\s*\\()'
  );
  private static final Set<String> CONSTANTS = new Set<String>{
    'true',
    'false',
    'null'
  };

  /**
   * Stops when a formula field on the path, or any formula it uses, reads a field the running user
   * cannot read.
   * @param objectApiName Object that owns the path
   * @param fieldPath Field path used by the template or data set
   */
  public static void requireReadableInputs(
    String objectApiName,
    String fieldPath
  ) {
    requireReadableInputs(objectApiName, fieldPath, new Set<String>(), 0);
  }

  private static Integer requireReadableInputs(
    String objectApiName,
    String fieldPath,
    Set<String> visited,
    Integer expansions
  ) {
    Schema.DescribeFieldResult description;
    try {
      description = PromptContextSchema.getTerminalFieldDescription(
        objectApiName,
        fieldPath
      );
    } catch (PromptContextException exceptionValue) {
      // The ordinary access checks report a missing or unreadable path.
      return expansions;
    }
    if (
      !description.isCalculated() ||
      String.isBlank(description.getCalculatedFormula())
    ) {
      return expansions;
    }
    String ownerObject = PromptContextSchema.terminalObjectName(
      objectApiName,
      fieldPath
    );
    String visitKey = (ownerObject + '.' + description.getName()).toLowerCase();
    if (visited.contains(visitKey)) {
      return expansions;
    }
    visited.add(visitKey);
    if (++expansions > MAX_FORMULA_EXPANSIONS) {
      throw unverified(fieldPath, 'uses more than ten nested formula fields');
    }
    for (String reference : references(description.getCalculatedFormula())) {
      try {
        PromptContextSchema.requireReadableFieldPath(ownerObject, reference);
      } catch (PromptContextException exceptionValue) {
        if (
          exceptionValue.reasonCode ==
          PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE
        ) {
          throw PromptContextException.withReason(
            PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
            'Formula field ' +
              fieldPath +
              ' uses a field you cannot read. Ask an administrator for access or remove the formula.'
          );
        }
        throw unverified(
          fieldPath,
          'uses ' + reference + ', which could not be checked'
        );
      }
      expansions = requireReadableInputs(
        ownerObject,
        reference,
        visited,
        expansions
      );
    }
    return expansions;
  }

  /**
   * Lists the record field paths a formula reads. Global values such as $User are not record
   * fields and are ignored; polymorphic references cannot be checked and stop the request.
   * @param formula Formula text from the field description
   * @return Field paths relative to the formula's object
   */
  @TestVisible
  private static Set<String> references(String formula) {
    String code = COMMENT.matcher(formula).replaceAll(' ');
    code = STRING_LITERAL.matcher(code).replaceAll('""');
    if (code.contains(':')) {
      throw PromptContextException.withReason(
        'FORMULA_INPUT_NOT_VERIFIED',
        'A formula uses a relationship to more than one object type, so its fields cannot be checked.'
      );
    }
    Set<String> paths = new Set<String>();
    Matcher matcher = REFERENCE.matcher(code);
    while (matcher.find()) {
      String candidate = matcher.group(1);
      if (!CONSTANTS.contains(candidate.toLowerCase())) {
        paths.add(candidate);
      }
    }
    return paths;
  }

  private static PromptContextException unverified(
    String fieldPath,
    String detail
  ) {
    return PromptContextException.withReason(
      'FORMULA_INPUT_NOT_VERIFIED',
      'Formula field ' + fieldPath + ' ' + detail + '.'
    );
  }

  private PromptContextFormulaAccess() {
  }
}
