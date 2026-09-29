/** Reads only Salesforce File metadata that the running user can access. */
public inherited sharing class PromptContextFileSelector {
  /** Returns exact selected versions and their direct current-record links. */
  public static List<ContentVersion> selectExactLinkedVersions(
    Id recordId,
    List<Id> contentVersionIds
  ) {
    if (
      recordId == null ||
      contentVersionIds == null ||
      contentVersionIds.isEmpty()
    ) {
      return new List<ContentVersion>();
    }
    Set<Id> requestedIds = new Set<Id>(contentVersionIds);
    List<ContentVersion> versions = [
      SELECT
        Id,
        ContentDocumentId,
        Title,
        FileExtension,
        FileType,
        ContentSize,
        IsLatest,
        VersionNumber,
        LastModifiedDate
      FROM ContentVersion
      WHERE Id IN :requestedIds
      WITH USER_MODE
      LIMIT 6
    ];
    Set<Id> documentIds = new Set<Id>();
    Map<Id, ContentVersion> versionById = new Map<Id, ContentVersion>();
    for (ContentVersion versionRecord : versions) {
      documentIds.add(versionRecord.ContentDocumentId);
      versionById.put(versionRecord.Id, versionRecord);
    }
    Set<Id> linkedDocumentIds = selectLinkedDocumentIds(recordId, documentIds);
    List<ContentVersion> ordered = new List<ContentVersion>();
    for (Id versionId : contentVersionIds) {
      ContentVersion versionRecord = versionById.get(versionId);
      if (
        versionRecord != null &&
        linkedDocumentIds.contains(versionRecord.ContentDocumentId)
      ) {
        ordered.add(versionRecord);
      }
    }
    return ordered;
  }

  /** Returns current versions after safely inspecting the directly linked file collection. */
  public static List<ContentVersion> selectLatestLinkedVersions(Id recordId) {
    if (recordId == null) {
      return new List<ContentVersion>();
    }
    Integer inspectionLimit =
      PromptContextContract.MAX_LINKED_FILES_INSPECTED + 1;
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :recordId
      WITH USER_MODE
      ORDER BY ContentDocumentId
      LIMIT :inspectionLimit
    ];
    if (links.size() > PromptContextContract.MAX_LINKED_FILES_INSPECTED) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.TOO_MANY_LINKED_FILES,
        'This record has more than 500 linked Salesforce Files. Narrow the record file collection before continuing.'
      );
    }
    Set<Id> documentIds = new Set<Id>();
    for (ContentDocumentLink linkRecord : links) {
      documentIds.add(linkRecord.ContentDocumentId);
    }
    if (documentIds.isEmpty()) {
      return new List<ContentVersion>();
    }
    return [
      SELECT
        Id,
        ContentDocumentId,
        Title,
        FileExtension,
        FileType,
        ContentSize,
        IsLatest,
        VersionNumber,
        LastModifiedDate
      FROM ContentVersion
      WHERE ContentDocumentId IN :documentIds AND IsLatest = TRUE
      WITH USER_MODE
      ORDER BY Title, Id
      LIMIT :inspectionLimit
    ];
  }

  private static Set<Id> selectLinkedDocumentIds(
    Id recordId,
    Set<Id> documentIds
  ) {
    Set<Id> linkedDocumentIds = new Set<Id>();
    if (documentIds.isEmpty()) {
      return linkedDocumentIds;
    }
    for (ContentDocumentLink linkRecord : [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :recordId AND ContentDocumentId IN :documentIds
      WITH USER_MODE
      LIMIT 6
    ]) {
      linkedDocumentIds.add(linkRecord.ContentDocumentId);
    }
    return linkedDocumentIds;
  }

  private PromptContextFileSelector() {
  }
}
