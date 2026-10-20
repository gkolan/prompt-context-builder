# Limits and defaults

These are hard safety and governor-limit boundaries owned by `PromptContextContract`.

| Limit                              |       Value | What to do                                                                  |
| ---------------------------------- | ----------: | --------------------------------------------------------------------------- |
| Sources per template               |          10 | Split unrelated context into another template                               |
| Selected fields per source         |          25 | Select only fields rendered or required by the query                        |
| Filters per source                 |          10 | Consolidate the business rule before adding another filter                  |
| Filter groups per source           |           5 | Keep related conditions in named groups                                     |
| Filter logic characters            |         255 | Simplify the logic; it can reference each filter number more than once      |
| Values in one Is one of list       |          50 | Use a broader rule or split the data set                                    |
| Relative date amount               |       4,000 | Use a smaller `n` in literals such as `LAST_N_DAYS:n`                       |
| maxLength attribute                | 1 to 20,000 | Choose the longest text the prompt needs from that field                    |
| Sort fields per source             |           3 | Use business order first; the service adds `Id` as a stable tiebreaker      |
| Rows per source                    |          50 | Start with the default of 10 and raise only when the prompt needs more rows |
| Rows across one prompt             |         200 | Later sources stop at the cap and return an explicit warning                |
| Input rows per calculated source   |       1,000 | Narrow filters; in Flow and Apex the cap covers every record in the request |
| Relationship depth                 |           5 | Flatten deeper context into another supported source                        |
| Template characters                |      20,000 | Remove repeated instructions or split the template                          |
| Generated prompt characters        |      20,000 | Reduce fields or source row limits                                          |
| Block iterations                   |         100 | Reduce collection sizes or block repetition                                 |
| Requests per API call              |         200 | Use Batch Apex for larger workloads                                         |
| Distinct templates per transaction |          10 | Group work by template                                                      |
| Flow response characters           |   1,000,000 | Reduce the Flow collection or use Batch Apex                                |
| Selected files per prepared input  |           5 | Select fewer files or narrow the published file settings                    |
| Bytes per selected file            |   4,500,000 | Use a smaller Salesforce File; an approved service can set a lower limit    |
| Bytes across selected files        |  22,500,000 | Reduce the number or size of selected files                                 |
| Linked files inspected             |         500 | Narrow the record's linked-file collection before continuing                |
| Eligible files per picker page     |          50 | Choose **Show more Files** to load the next page                            |
| Approved service review age        |     90 days | Recheck the service and update its Last Verified Date                       |
| Logs claimed by one worker         |          25 | Run another worker for the remaining Ready records                          |
| Delivery attempts per saved input  |           3 | Investigate the final failure before an administrator starts new work       |
| Prompt Input Log retention         |     30 days | Schedule the purge job, or delete or archive under your retention policy    |
| Template list page size            | 100 maximum | Page through results; the default is 50                                     |

During generation, Prompt Context Builder can lower the safe record count when little Salesforce
record-read capacity remains. Callers must respect that limit and leave capacity for their own
work.

Record limits are saved choices, not hidden shortening. A data set that has more visible matches
than its saved maximum returns the first records in the chosen order and `SOURCE_TRUNCATED`. Once
the combined 200-record maximum is reached, later data sets return no records and `TOTAL_ROW_LIMIT`.
The final 20,000-character limit is different: exceeding it returns no prompt.

The file count and byte limits are complete-request rules. User-selected mode rejects a sixth file.
All Eligible mode uses the first eligible files in stable Title and Id order, up to the effective
template and approved-service limit. The service never shortens a file. Published template settings
and the approved service setup may lower a file limit but cannot raise these package limits.
