using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using StreamMaster.Application.StreamGroupSMChannelLinks.Commands;
using StreamMaster.Application.StreamGroupSMChannelLinks.Queries;

namespace StreamMaster.Application.StreamGroupSMChannelLinks
{
    public interface IStreamGroupSMChannelLinksController
    {
        Task<ActionResult<List<SMChannelDto>>> GetStreamGroupSMChannels(GetStreamGroupSMChannelsRequest request);
        Task<ActionResult<APIResponse?>> AddSMChannelsToStreamGroupByParameters(AddSMChannelsToStreamGroupByParametersRequest request);
        Task<ActionResult<APIResponse?>> AddSMChannelsToStreamGroup(AddSMChannelsToStreamGroupRequest request);
        Task<ActionResult<APIResponse?>> AddSMChannelToStreamGroup(AddSMChannelToStreamGroupRequest request);
        Task<ActionResult<APIResponse?>> RemoveSMChannelFromStreamGroup(RemoveSMChannelFromStreamGroupRequest request);
    }
}

namespace StreamMaster.Application.Hubs
{
    public interface IStreamGroupSMChannelLinksHub
    {
        Task<List<SMChannelDto>> GetStreamGroupSMChannels(GetStreamGroupSMChannelsRequest request);
        Task<APIResponse?> AddSMChannelsToStreamGroupByParameters(AddSMChannelsToStreamGroupByParametersRequest request);
        Task<APIResponse?> AddSMChannelsToStreamGroup(AddSMChannelsToStreamGroupRequest request);
        Task<APIResponse?> AddSMChannelToStreamGroup(AddSMChannelToStreamGroupRequest request);
        Task<APIResponse?> RemoveSMChannelFromStreamGroup(RemoveSMChannelFromStreamGroupRequest request);
    }
}
