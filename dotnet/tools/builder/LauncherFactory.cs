using System;
using System.IO;

namespace MyRulesDotnet.Tools.Builder
{
    /// <summary>
    /// https://docs.google.com/document/d/1z6Xv95CJYNYNYylcRklA6xBeesNLc54dqXfri0z0e14/edit#heading=h.ehp217t4xp3w
    /// </summary>
    public class LauncherFactory
    {
        public LauncherFactory()
        {
        }

        public void Create(string[] args)
        {
            var launcherTemplate = new FileInfo(args[0]);
            if (!launcherTemplate.Exists)
                throw new Exception($"Launcher template does not exist at '{args[0]}'");

            using var output = new FileInfo(args[1]).OpenWrite();
            using (var input = launcherTemplate.OpenRead())
            {
                input.CopyTo(output);
            }

            var writer = new LaunchDataWriter()
                // see: //dotnet/tools/launcher/windows:launcher_main.cc
                .Add("binary_type", "Dotnet");

            for (int i = 2; i + 1 < args.Length; i++)
            {
                writer.Add(args[i], args[i + 1]);
            }

            writer.Write(output);
        }
    }
}