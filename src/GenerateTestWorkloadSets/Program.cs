using GenerateTestWorkloadSets;
using System.Text;

List<WorkloadSetInfo> workloadSetsToCreate = [
    new WorkloadSetInfo("9.0.100", ReleasedWorkloadVersions.Rollback9_0_100_preview7_24414_1),
    new WorkloadSetInfo("9.0.101-servicing.preview.1", ReleasedWorkloadVersions.Rollback9_0_100_preview7_and_rc1),
    new WorkloadSetInfo("9.0.101", ReleasedWorkloadVersions.Rollback9_0_100_rc1_24453_3)
];

StringBuilder buildScript = new();
foreach (var workloadSetInfo in workloadSetsToCreate)
{
    ProcessWorkloadSet(workloadSetInfo, buildScript, Environment.CurrentDirectory);
}

buildScript.AppendLine("@echo Done");
buildScript.AppendLine();
buildScript.AppendLine(":End");

var buildScriptPath = Path.GetFullPath("buildWorkloads.bat");
File.WriteAllText(buildScriptPath, buildScript.ToString());
Console.WriteLine("Build script path: " + buildScriptPath);

static void ProcessWorkloadSet(WorkloadSetInfo workloadSetInfo, StringBuilder buildScript, string outputPath)
{
    string workloadsPropsOutput = Path.Combine(outputPath, $"workloads-{workloadSetInfo.WorkloadSetVersion}.props");
    File.WriteAllText(workloadsPropsOutput, workloadSetInfo.ToWorkloadsProps());

    List<string> buildArgs = [
        .. WorkloadSetProperties.CreateFromWorkloadSetVersion(workloadSetInfo.WorkloadSetVersion).CreateCommandLineArgs(),
        $"/p:WorkloadsProps={workloadsPropsOutput}",
    ];

    buildScript.AppendLine("@echo Building workload set " + workloadSetInfo.WorkloadSetVersion);
    buildScript.AppendLine("call build -bl " + string.Join(' ', buildArgs));
    buildScript.AppendLine("IF ERRORLEVEL 1 GOTO END");
    buildScript.AppendLine();
}