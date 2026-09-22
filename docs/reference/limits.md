# Limits and defaults

These are hard safety and governor-limit boundaries owned by `PromptContextContract`.

| Limit                              |       Value | What to do                                                                  |
| ---------------------------------- | ----------: | --------------------------------------------------------------------------- |
| Sources per template               |          10 | Split unrelated context into another template                               |
| Selected fields per source         |          25 | Select only fields rendered or required by the query                        |
| Filters per source                 |          10 | Consolidate the business rule before adding another filter                  |
| Filter groups per source           |           5 | Keep related conditions in named groups                                     |
| Sort fields per source             |           3 | Use business order first; the service adds `Id` as a stable tiebreaker      |
| Rows per source                    |          50 | Start with the default of 10 and raise only when the prompt needs more rows |
| Rows across one prompt             |         200 | Later sources stop at the cap and return an explicit warning                |
| Relationship depth                 |           5 | Flatten deeper context into another supported source                        |
| Template characters                |      20,000 | Remove repeated instructions or split the template                          |
| Generated prompt characters        |      20,000 | Reduce fields or source row limits                                          |
| Block iterations                   |         100 | Reduce collection sizes or block repetition                                 |
| Requests per API call              |         200 | Use Batch Apex for larger workloads                                         |
| Distinct templates per transaction |          10 | Group work by template                                                      |
| Flow response characters           |   1,000,000 | Reduce the Flow collection or use Batch Apex                                |
| Template list page size            | 100 maximum | Page through results; the default is 50                                     |

During generation, Prompt Context Builder can lower the safe record count when little Salesforce
record-read capacity remains. Callers must respect that limit and leave capacity for their own
work.

Record limits are saved choices, not hidden shortening. A data set that has more visible matches
than its saved maximum returns the first records in the chosen order and `SOURCE_TRUNCATED`. Once
the combined 200-record maximum is reached, later data sets return no records and `TOTAL_ROW_LIMIT`.
The final 20,000-character limit is different: exceeding it returns no prompt.
