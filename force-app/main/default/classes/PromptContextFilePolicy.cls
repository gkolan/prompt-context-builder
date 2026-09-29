/** Applies the published Salesforce File policy before prepared input can be returned or saved. */
public with sharing class PromptContextFilePolicy {
  private static final Set<String> PACKAGE_FORMATS = new Set<String>{
    'csv',
    'doc',
    'docx',
    'html',
    'md',
    'pdf',
    'txt',
    'xls',
    'xlsx'
  };

  /** One exact Salesforce File version approved for this prepared input. */
  public class SelectedFile {
    public Integer order;
    public Id contentDocumentId;
    public Id contentVersionId;
    public String fileName;
    public String fileFormat;
    public Integer sizeInBytes;
    public Integer versionNumber;
    public Datetime lastModifiedDate;
  }

  /** Ordered selected files plus the canonical managed JSON representation. */
  public class Selection {
    public List<SelectedFile> files = new List<SelectedFile>();
    public String selectedFilesJson = '[]';
  }

  /**
   * Resolves and validates the exact Salesforce File versions for one prepared input.
   * @param config Published template configuration
   * @param recordId Current Salesforce record
   * @param selectedContentVersionIds Exact versions chosen by the caller
   * @return Canonically ordered selected-file details
   */
  public static Selection selectFiles(
    PromptContextDTO.TemplateConfig config,
    Id recordId,
    List<Id> selectedContentVersionIds
  ) {
    validateConfiguration(config);
    String mode = config.fileInputMode;
    List<Id> requestedIds = selectedContentVersionIds ?? new List<Id>();
    if (requestedIds.size() != new Set<Id>(requestedIds).size()) {
      fail(
        PromptContextReasonCodes.INVALID_REQUEST,
        'Choose each Salesforce File only once.'
      );
    }
    if (mode == 'DISABLED') {
      if (!requestedIds.isEmpty()) {
        fail(
          PromptContextReasonCodes.FILES_NOT_ENABLED,
          'This published prompt does not accept Salesforce Files.'
        );
      }
      return new Selection();
    }
    PromptContextAccess.requireSendFiles();
    PromptContextProviderSettings.Settings provider = PromptContextProviderSettings.requireActive(
      config.providerProfileKey
    );
    Integer effectiveLimit = Math.min(
      Math.min(config.maxFiles, provider.maximumFiles),
      PromptContextContract.MAX_SELECTED_FILES
    );
    if (requestedIds.size() > effectiveLimit) {
      failTooMany(effectiveLimit);
    }

    List<ContentVersion> versions;
    if (mode == 'ALL_ELIGIBLE') {
      if (!requestedIds.isEmpty()) {
        fail(
          PromptContextReasonCodes.INVALID_REQUEST,
          'Do not choose individual files when the prompt uses all eligible files.'
        );
      }
      versions = eligibleVersions(
        PromptContextFileSelector.selectLatestLinkedVersions(recordId),
        effectiveFormats(
          config.allowedFileFormats,
          provider.allowedFileFormats
        ),
        provider.maximumFileBytes
      );
      while (versions.size() > effectiveLimit) {
        versions.remove(versions.size() - 1);
      }
    } else {
      versions = PromptContextFileSelector.selectExactLinkedVersions(
        recordId,
        requestedIds
      );
      if (versions.size() != new Set<Id>(requestedIds).size()) {
        fail(
          PromptContextReasonCodes.FILE_NOT_LINKED_TO_RECORD,
          'One or more selected Salesforce Files are unavailable or are not linked directly to this record.'
        );
      }
    }
    if (config.requireAtLeastOneFile == true && versions.isEmpty()) {
      fail(
        PromptContextReasonCodes.FILE_REQUIRED,
        'Select at least one eligible Salesforce File before continuing.'
      );
    }
    return buildSelection(
      versions,
      effectiveFormats(config.allowedFileFormats, provider.allowedFileFormats),
      provider.maximumFileBytes
    );
  }

  /** Returns eligible current file versions for the record-page picker. */
  public static PromptContextDTO.FileChoicePage getFileChoices(
    PromptContextDTO.TemplateConfig config,
    Id recordId,
    String afterTitle,
    Id afterId
  ) {
    validateConfiguration(config);
    PromptContextDTO.FileChoicePage page = new PromptContextDTO.FileChoicePage();
    if (config.fileInputMode == 'DISABLED') {
      return page;
    }
    PromptContextAccess.requireSendFiles();
    PromptContextProviderSettings.Settings provider = PromptContextProviderSettings.requireActive(
      config.providerProfileKey
    );
    Set<String> permittedFormats = effectiveFormats(
      config.allowedFileFormats,
      provider.allowedFileFormats
    );
    List<ContentVersion> versions = PromptContextFileSelector.selectLatestLinkedVersions(
      recordId
    );
    ContentVersion lastAddedVersion;
    for (
      ContentVersion versionRecord : versionsAfterCursor(
        versions,
        afterTitle,
        afterId
      )
    ) {
      String format = (versionRecord.FileExtension ?? '').toLowerCase();
      if (
        !permittedFormats.contains(format) ||
        versionRecord.ContentSize == null ||
        versionRecord.ContentSize <= 0 ||
        versionRecord.ContentSize >
        Math.min(
          PromptContextContract.MAX_FILE_BYTES,
          provider.maximumFileBytes
        )
      ) {
        continue;
      }
      if (page.items.size() == PromptContextContract.FILE_PICKER_PAGE_SIZE) {
        page.hasMore = true;
        break;
      }
      PromptContextDTO.FileChoice item = new PromptContextDTO.FileChoice();
      item.contentVersionId = versionRecord.Id;
      item.label = versionRecord.Title + '.' + format;
      item.fileFormat = format;
      item.sizeInBytes = versionRecord.ContentSize;
      page.items.add(item);
      lastAddedVersion = versionRecord;
    }
    if (page.hasMore && lastAddedVersion != null) {
      page.nextTitle = lastAddedVersion.Title;
      page.nextId = lastAddedVersion.Id;
    }
    return page;
  }

  private static List<ContentVersion> versionsAfterCursor(
    List<ContentVersion> versions,
    String afterTitle,
    Id afterId
  ) {
    if (String.isBlank(afterTitle) && afterId == null) {
      return versions;
    }
    if (String.isBlank(afterTitle) || afterId == null) {
      fail(
        PromptContextReasonCodes.INVALID_REQUEST,
        'Refresh the Salesforce File list and try again.'
      );
    }
    Boolean cursorFound = false;
    List<ContentVersion> remaining = new List<ContentVersion>();
    for (ContentVersion versionRecord : versions) {
      if (cursorFound) {
        remaining.add(versionRecord);
      } else if (
        versionRecord.Id == afterId &&
        versionRecord.Title == afterTitle
      ) {
        cursorFound = true;
      }
    }
    if (!cursorFound) {
      fail(
        PromptContextReasonCodes.INVALID_REQUEST,
        'Refresh the Salesforce File list and try again.'
      );
    }
    return remaining;
  }

  /** Validates the file settings stored with a draft or published template. */
  public static void validateConfiguration(
    PromptContextDTO.TemplateConfig config
  ) {
    if (config == null) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The prompt file settings are missing.'
      );
    }
    String mode = config.fileInputMode;
    if (mode == 'DISABLED') {
      if (config.requireAtLeastOneFile == true) {
        fail(
          PromptContextReasonCodes.INVALID_CONFIGURATION,
          'A disabled file input cannot require a file.'
        );
      }
      return;
    }
    if (mode != 'USER_SELECT' && mode != 'ALL_ELIGIBLE') {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Choose a supported File Input Mode.'
      );
    }
    if (
      config.maxFiles == null ||
      config.maxFiles < 1 ||
      config.maxFiles > PromptContextContract.MAX_SELECTED_FILES
    ) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Maximum Files must be from 1 through 5.'
      );
    }
    if (String.isBlank(config.providerProfileKey)) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Choose an approved Provider Profile before enabling file input.'
      );
    }
    PromptContextProviderSettings.Settings provider = PromptContextProviderSettings.requireActive(
      config.providerProfileKey
    );
    if (
      config.fileCitationsEnabled == true &&
      provider.supportsCitations != true
    ) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template requires file citations that the approved service does not support.'
      );
    }
    Set<String> configuredFormats = new Set<String>();
    Boolean containsUnsupportedFormat = false;
    for (String item : (config.allowedFileFormats ?? '').split(',')) {
      String normalized = item.trim().toLowerCase();
      if (String.isBlank(normalized)) {
        continue;
      }
      configuredFormats.add(normalized);
      containsUnsupportedFormat =
        containsUnsupportedFormat || !PACKAGE_FORMATS.contains(normalized);
    }
    if (configuredFormats.isEmpty() || containsUnsupportedFormat) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Use only these file formats: pdf, csv, doc, docx, xls, xlsx, html, txt, or md.'
      );
    }
  }

  private static Selection buildSelection(
    List<ContentVersion> versions,
    Set<String> allowedFormats,
    Integer providerMaximumFileBytes
  ) {
    Selection selection = new Selection();
    Integer totalBytes = 0;
    Integer position = 0;
    for (ContentVersion versionRecord : versions) {
      position++;
      if (versionRecord.IsLatest != true) {
        fail(
          PromptContextReasonCodes.FILE_VERSION_STALE,
          'A selected Salesforce File version is no longer current. Refresh the file list and choose the latest version.'
        );
      }
      String format = (versionRecord.FileExtension ?? '').toLowerCase();
      if (
        !PACKAGE_FORMATS.contains(format) || !allowedFormats.contains(format)
      ) {
        fail(
          PromptContextReasonCodes.UNSUPPORTED_FILE_TYPE,
          'The selected Salesforce File format is not allowed for this prompt.'
        );
      }
      if (versionRecord.ContentSize == null || versionRecord.ContentSize <= 0) {
        fail(
          PromptContextReasonCodes.FILE_SECURITY_REJECTED,
          'A selected Salesforce File is empty and cannot be sent.'
        );
      }
      if (
        versionRecord.ContentSize >
        Math.min(PromptContextContract.MAX_FILE_BYTES, providerMaximumFileBytes)
      ) {
        fail(
          PromptContextReasonCodes.FILE_TOO_LARGE,
          'A selected Salesforce File is larger than the allowed size.'
        );
      }
      totalBytes += versionRecord.ContentSize;
      if (totalBytes > PromptContextContract.MAX_TOTAL_FILE_BYTES) {
        fail(
          PromptContextReasonCodes.TOTAL_FILE_BYTES_EXCEEDED,
          'The selected Salesforce Files are too large as one request.'
        );
      }
      SelectedFile selected = new SelectedFile();
      selected.order = position;
      selected.contentDocumentId = versionRecord.ContentDocumentId;
      selected.contentVersionId = versionRecord.Id;
      selected.fileName = versionRecord.Title + '.' + format;
      selected.fileFormat = format;
      selected.sizeInBytes = versionRecord.ContentSize;
      selected.versionNumber = Integer.valueOf(versionRecord.VersionNumber);
      selected.lastModifiedDate = versionRecord.LastModifiedDate;
      selection.files.add(selected);
    }
    selection.selectedFilesJson = JSON.serialize(selection.files);
    return selection;
  }

  private static List<ContentVersion> eligibleVersions(
    List<ContentVersion> versions,
    Set<String> allowedFormats,
    Integer providerMaximumFileBytes
  ) {
    Integer byteLimit = Math.min(
      PromptContextContract.MAX_FILE_BYTES,
      providerMaximumFileBytes
    );
    List<ContentVersion> eligible = new List<ContentVersion>();
    for (ContentVersion versionRecord : versions) {
      String format = (versionRecord.FileExtension ?? '').toLowerCase();
      if (
        PACKAGE_FORMATS.contains(format) &&
        allowedFormats.contains(format) &&
        versionRecord.ContentSize != null &&
        versionRecord.ContentSize > 0 &&
        versionRecord.ContentSize <= byteLimit
      ) {
        eligible.add(versionRecord);
      }
    }
    return eligible;
  }

  private static Set<String> allowedFormats(String value) {
    Set<String> formats = new Set<String>();
    for (String item : (value ?? '').split(',')) {
      String normalized = item.trim().toLowerCase();
      if (!String.isBlank(normalized) && PACKAGE_FORMATS.contains(normalized)) {
        formats.add(normalized);
      }
    }
    return formats;
  }

  private static Set<String> effectiveFormats(
    String templateFormats,
    String providerFormats
  ) {
    Set<String> effective = allowedFormats(templateFormats);
    effective.retainAll(allowedFormats(providerFormats));
    if (effective.isEmpty()) {
      fail(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template and approved service setup do not share a supported file format.'
      );
    }
    return effective;
  }

  private static void failTooMany(Integer effectiveLimit) {
    fail(
      PromptContextReasonCodes.TOO_MANY_FILES,
      'Select no more than ' + effectiveLimit + ' Salesforce Files.'
    );
  }

  private static void fail(String reasonCode, String message) {
    throw PromptContextException.withReason(reasonCode, message);
  }

  private PromptContextFilePolicy() {
  }
}
