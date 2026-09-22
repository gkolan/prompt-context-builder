for (CronTrigger job : [
  SELECT Id
  FROM CronTrigger
  WHERE CronJobDetail.Name = 'Prompt Template Health - Daily 2AM'
]) {
  System.abortJob(job.Id);
}
