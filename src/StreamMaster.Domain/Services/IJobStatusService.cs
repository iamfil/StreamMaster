﻿namespace StreamMaster.Domain.Services
{
    public interface IJobStatusService
    {
        JobStatusManager GetJobManagerProcessEPG(int id);
        JobStatusManager GetJobManagerRefreshEPG(int id);
        JobStatusManager GetJobManagerUpdateEPG(int id);
        JobStatusManager GetJobManagerUpdateM3U(int id);
        JobStatusManager GetJobManagerProcessM3U(int id);
        JobStatusManager GetJobManagerRefreshM3U(int id);
        JobStatusManager GetJobManageSDSync(int id);
        DateTime LastRun(string key);
        DateTime LastSuccessful(string key);
        JobStatusManager GetJobManager(JobType jobType, int id);
        bool IsRunning(string key);

        bool IsErrored(string key);
        bool ForceNextRun(string key);
        void SetIsRunning(string key, bool isRunning);
        void SetSuccessful(string key);
        void SetError(string key);
        void ClearForce(string key);
        void SetForceNextRun(string key, bool extra = false);
        JobStatus GetStatus(string key);
    }
}