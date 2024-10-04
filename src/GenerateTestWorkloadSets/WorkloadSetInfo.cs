using Microsoft.DotNet.Workloads.Workload;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace GenerateTestWorkloadSets
{
    internal class WorkloadSetInfo
    {

        public string WorkloadSetVersion { get; set; }


        public List<WorkloadManifestInfo> Manifests { get; set; } = new();

        public WorkloadSetInfo()
        {
            
        }

        public WorkloadSetInfo(string workloadSetVersion, string rollbackJson)
        {
            WorkloadSetVersion = workloadSetVersion;
            LoadManifests(rollbackJson);
        }

        public void LoadManifests(string rollbackJson)
        {
            Manifests.Clear();

            var jsonDictionary = JsonSerializer.Deserialize<Dictionary<string,string>>(rollbackJson);

            foreach (var kvp in jsonDictionary)
            {
                string name = kvp.Key;
                var valueParts = kvp.Value.Split('/');
                string version = valueParts[0];
                string featureBand = valueParts[1];

                Manifests.Add(new WorkloadManifestInfo(name, featureBand, version));
            }
        }

        public string ToWorkloadsProps()
        {
            StringBuilder sb = new StringBuilder();

            sb.AppendLine("<Project>");
            sb.AppendLine("  <ItemGroup>");
            foreach (var manifest in Manifests)
            {
                sb.AppendLine($"""    <WorkloadManifest Include="{manifest.Name}" FeatureBand="{manifest.FeatureBand}" Version="{manifest.Version}" />""");
            }
            sb.AppendLine("  </ItemGroup>");
            sb.AppendLine("</Project>");

            return sb.ToString();
        }
    }

    internal class WorkloadSetProperties
    {
        public string WorkloadSetVersion { get; set; }
        public string VersionMajor { get; set; }
        public string VersionMinor { get; set; }
        public string VersionSdkMinor { get; set; }
        public string VersionFeature { get; set; }
        public string VersionPatch { get; set; }
        public string SdkFeatureBand { get; set; }

        public string Version { get; set; }

        public static WorkloadSetProperties CreateFromWorkloadSetVersion(string workloadSetVersion)
        {
            WorkloadSetProperties ret = new WorkloadSetProperties();
            ret.WorkloadSetVersion = workloadSetVersion;

            string[] sections = workloadSetVersion.Split(new char[] { '-', '+' }, 2);
            string versionCore = sections[0];
            string? preReleaseOrBuild = sections.Length > 1 ? sections[1] : null;

            string[] coreComponents = versionCore.Split('.');
            string major = coreComponents[0];
            string minor = coreComponents[1];
            string patch = coreComponents[2];

            ret.VersionMajor = major;
            ret.VersionMinor = minor;
            ret.VersionSdkMinor = (int.Parse(patch) / 100).ToString();
            ret.VersionFeature = (int.Parse(patch) % 100).ToString("d2");

            if (coreComponents.Length == 3)
            {
                ret.VersionPatch = "0";
            }
            else
            {
                ret.VersionPatch = coreComponents[3];
            }

            ret.SdkFeatureBand = Microsoft.DotNet.Workloads.Workload.WorkloadSetVersion.GetFeatureBand(workloadSetVersion).ToString();
            ret.Version = Microsoft.DotNet.Workloads.Workload.WorkloadSetVersion.ToWorkloadSetPackageVersion(workloadSetVersion, out _);

            return ret;
        }

        public string[] CreateCommandLineArgs()
        {
            return
                [
                    $"/p:VersionMajor={VersionMajor}",
                    $"/p:VersionMinor={VersionMinor}",
                    $"/p:VersionSdkMinor={VersionSdkMinor}",
                    $"/p:VersionFeature={VersionFeature}",
                    $"/p:VersionPatch={VersionPatch}",
                    $"/p:Version={Version}",
                    $"/p:SdkFeatureBand={SdkFeatureBand}",
                    $"/p:WorkloadsVersion={WorkloadSetVersion}",
                ];
        }

    }

    internal record WorkloadManifestInfo(string Name, string FeatureBand, string Version);
    
}
