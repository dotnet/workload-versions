using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GenerateTestWorkloadSets
{
    internal class ReleasedWorkloadVersions
    {
        public static string Rollback9_0_100_preview7_24414_1 = """
            {
              "Microsoft.NET.Workload.Emscripten.Current": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net6": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net7": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net8": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Android": "35.0.0-preview.7.41/9.0.100-preview.7",
              "Microsoft.NET.Sdk.iOS": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.MacCatalyst": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.macOS": "14.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Maui": "9.0.0-preview.7.24407.4/9.0.100-preview.7",
              "Microsoft.NET.Sdk.tvOS": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.Current": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net6": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net7": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net8": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Aspire": "8.1.0/8.0.100"
            }
            """;

        //  A combination of preview 7 and rc1 manifest versions
        public static string Rollback9_0_100_preview7_and_rc1 = """
            {
              "Microsoft.NET.Workload.Emscripten.Current": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net6": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net7": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Workload.Emscripten.net8": "9.0.0-preview.7.24373.5/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Android": "35.0.0-preview.7.41/9.0.100-preview.7",
              "Microsoft.NET.Sdk.iOS": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.MacCatalyst": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.macOS": "14.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Maui": "9.0.0-preview.7.24407.4/9.0.100-preview.7",
              "Microsoft.NET.Sdk.tvOS": "17.5.9231-net9-p7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.Current": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net6": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net7": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Workload.Mono.ToolChain.net8": "9.0.0-preview.7.24405.7/9.0.100-preview.7",
              "Microsoft.NET.Sdk.Aspire": "8.2.0/8.0.100"
            }
            """;

        public static string Rollback9_0_100_rc1_24453_3 = """
            {
              "Microsoft.NET.Workload.Emscripten.Current": "9.0.0-rc.1.24430.3/9.0.100-rc.1",
              "Microsoft.NET.Workload.Emscripten.net6": "9.0.0-rc.1.24430.3/9.0.100-rc.1",
              "Microsoft.NET.Workload.Emscripten.net7": "9.0.0-rc.1.24430.3/9.0.100-rc.1",
              "Microsoft.NET.Workload.Emscripten.net8": "9.0.0-rc.1.24430.3/9.0.100-rc.1",
              "Microsoft.NET.Sdk.Android": "35.0.0-rc.1.80/9.0.100-rc.1",
              "Microsoft.NET.Sdk.iOS": "17.5.9270-net9-rc1/9.0.100-rc.1",
              "Microsoft.NET.Sdk.MacCatalyst": "17.5.9270-net9-rc1/9.0.100-rc.1",
              "Microsoft.NET.Sdk.macOS": "14.5.9270-net9-rc1/9.0.100-rc.1",
              "Microsoft.NET.Sdk.Maui": "9.0.0-rc.1.24453.9/9.0.100-rc.1",
              "Microsoft.NET.Sdk.tvOS": "17.5.9270-net9-rc1/9.0.100-rc.1",
              "Microsoft.NET.Workload.Mono.ToolChain.Current": "9.0.0-rc.1.24431.7/9.0.100-rc.1",
              "Microsoft.NET.Workload.Mono.ToolChain.net6": "9.0.0-rc.1.24431.7/9.0.100-rc.1",
              "Microsoft.NET.Workload.Mono.ToolChain.net7": "9.0.0-rc.1.24431.7/9.0.100-rc.1",
              "Microsoft.NET.Workload.Mono.ToolChain.net8": "9.0.0-rc.1.24431.7/9.0.100-rc.1",
              "Microsoft.NET.Sdk.Aspire": "8.2.0/8.0.100"
            }
            """;
    }
}
