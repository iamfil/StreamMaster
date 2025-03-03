using System.Text.Json.Serialization;

namespace StreamMaster.Domain.Configuration;

[TsInterface(AutoI = false, IncludeNamespace = false, FlattenHierarchy = true, AutoExportMethods = false)]
public class CommandProfile
{
    public bool IsReadOnly { get; set; } = false;
    public string Command { get; set; } = "ffmpeg";
    public string Parameters { get; set; } = "";
}

[TsInterface(AutoI = false, IncludeNamespace = false, FlattenHierarchy = true, AutoExportMethods = false)]
public class CommandProfileDto : CommandProfile
{
    public string ProfileName { get; set; } = "";
}

public class CommandProfileDict : IProfileDict<CommandProfile>
{
    [JsonPropertyName("CommandProfiles")]
    public Dictionary<string, CommandProfile> CommandProfiles { get; set; } = [];

    public CommandProfile? GetProfile(string CommandProfileName)
    {
        return Profiles.TryGetValue(CommandProfileName, out CommandProfile? existingProfile)
            ? existingProfile
            : null;
    }

    [JsonIgnore]
    public Dictionary<string, CommandProfile> Profiles => CommandProfiles;

    public bool HasProfile(string CommandProfileName)
    {
        return Profiles.TryGetValue(CommandProfileName, out _);
    }

    public CommandProfileDto GetProfileDto(string CommandProfileName)
    {
        return GetDefaultProfileDto(CommandProfileName);
    }

    public CommandProfileDto GetDefaultProfileDto(string defaultName = "Default")
    {
        CommandProfile? defaultProfile = GetProfile(defaultName);
        return defaultProfile == null
            ? throw new Exception($"Command Profile {defaultName} not found")
            : GetProfileDtoFromProfile(defaultProfile, defaultName);
    }

    public static CommandProfileDto GetProfileDtoFromProfile(CommandProfile commandProfile, string ProfileName)
    {
        return new CommandProfileDto
        {
            Command = commandProfile.Command,
            ProfileName = ProfileName,
            IsReadOnly = commandProfile.IsReadOnly,
            Parameters = commandProfile.Parameters,
        };
    }

    public List<CommandProfileDto> GetProfilesDto()
    {
        List<CommandProfileDto> ret = [];

        foreach (string key in Profiles.Keys)
        {
            if (Profiles.TryGetValue(key, out CommandProfile? profile))
            {
                ret.Add(GetProfileDtoFromProfile(profile, key));
            }
        }
        return ret;
    }

    public List<CommandProfile> GetProfiles()
    {
        List<CommandProfile> ret = [];

        foreach (string key in Profiles.Keys)
        {
            if (Profiles.TryGetValue(key, out CommandProfile? profile))
            {
                ret.Add(profile);
            }
        }
        return ret;
    }

    public void AddProfile(string ProfileName, CommandProfile Profile)
    {
        CommandProfiles.Add(ProfileName, Profile);
    }

    public void AddProfiles(Dictionary<string, dynamic> profiles)
    {
        CommandProfiles = profiles.ToDictionary(
            kvp => kvp.Key,
            kvp => (CommandProfile)kvp.Value
        );
    }

    public void RemoveProfile(string ProfileName)
    {
        CommandProfiles.Remove(ProfileName);
    }

    public bool IsReadOnly(string ProfileName)
    {
        return GetProfile(ProfileName)?.IsReadOnly ?? false;
    }
}