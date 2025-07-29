using Microsoft.Deployment.DotNet.Releases;

namespace GenerateTestWorkloadSets;

public readonly struct SdkFeatureBand : IEquatable<SdkFeatureBand>, IComparable<SdkFeatureBand>
{
    private readonly ReleaseVersion _featureBand;

    public SdkFeatureBand(string? version) : this(new ReleaseVersion(version) ?? throw new ArgumentNullException(nameof(version))) { }

    public SdkFeatureBand(ReleaseVersion version)
    {
        var fullVersion = version ?? throw new ArgumentNullException(nameof(version));
        if (string.IsNullOrEmpty(version.Prerelease) || version.Prerelease.Contains("dev") || version.Prerelease.Contains("ci") || version.Prerelease.Contains("rtm"))
        {
            _featureBand = new ReleaseVersion(fullVersion.Major, fullVersion.Minor, fullVersion.SdkFeatureBand);
        }
        else
        {
            // Treat preview versions as their own feature bands
            var prereleaseComponents = fullVersion.Prerelease.Split('.');
            var formattedPrerelease = prereleaseComponents.Length > 1 ?
                $"{prereleaseComponents[0]}.{prereleaseComponents[1]}"
                : prereleaseComponents[0];
            _featureBand = new ReleaseVersion(fullVersion.Major, fullVersion.Minor, fullVersion.SdkFeatureBand, formattedPrerelease);
        }
    }

    public readonly int Major => _featureBand.Major;
    public readonly int Minor => _featureBand.Minor;

    public readonly bool Equals(SdkFeatureBand other)
    {
        return _featureBand.Equals(other._featureBand);
    }

    public readonly int CompareTo(SdkFeatureBand other)
    {
        return _featureBand.CompareTo(other._featureBand);
    }

    public readonly override bool Equals(object? obj)
    {
        return obj is SdkFeatureBand featureBand && Equals(featureBand);
    }

    public readonly override int GetHashCode()
    {
        return _featureBand.GetHashCode();
    }

    public readonly override string ToString()
    {
        return _featureBand.ToString();
    }

    public readonly string ToStringWithoutPrerelease()
    {
        return new ReleaseVersion(_featureBand.Major, _featureBand.Minor, _featureBand.SdkFeatureBand).ToString();
    }

    public static bool operator >(SdkFeatureBand a, SdkFeatureBand b) => a.CompareTo(b) > 0;

    public static bool operator <(SdkFeatureBand a, SdkFeatureBand b) => a.CompareTo(b) < 0;
}
