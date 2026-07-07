# Stale Class Error — ComprehensiveMatrixIT

## Error

```
[ERROR] Bad type on operand stack
Exception Details:
  Location:
    com/harness/sample/it/ComprehensiveMatrixIT.test7_allCombinationsParallel()V @66: invokedynamic
  Reason:
    Type '[Z' (current frame, stack[5]) is not assignable to '[[Z'
  Current Frame:
    bci: @66
    flags: { }
    locals: { 'com/harness/sample/it/ComprehensiveMatrixIT', 'com/harness/sample/it/ComprehensiveMatrixIT', '[Ljava/lang/Thread;', '[Z', '[Z', 'com/harness/sample/it/ComprehensiveMatrixIT' }
    stack: { '[Ljava/lang/Thread;', integer, uninitialized 50, uninitialized 50, 'com/harness/sample/it/ComprehensiveMatrixIT', '[Z' }
```

## Stack Trace

```
org.apache.maven.surefire.booter.SurefireBooterForkException: There was an error in the forked process
Bad type on operand stack
        at org.apache.maven.plugin.surefire.booterclient.ForkStarter.fork(ForkStarter.java:628)
        at org.apache.maven.plugin.surefire.booterclient.ForkStarter.run(ForkStarter.java:285)
        at org.apache.maven.plugin.surefire.booterclient.ForkStarter.run(ForkStarter.java:250)
        at org.apache.maven.plugin.surefire.AbstractSurefireMojo.executeProvider(AbstractSurefireMojo.java:1203)
        at org.apache.maven.plugin.surefire.AbstractSurefireMojo.executeAfterPreconditionsChecked(AbstractSurefireMojo.java:1055)
        at org.apache.maven.plugin.surefire.AbstractSurefireMojo.execute(AbstractSurefireMojo.java:871)
        at org.apache.maven.plugin.DefaultBuildPluginManager.executeMojo(DefaultBuildPluginManager.java:126)
        at org.apache.maven.lifecycle.internal.MojoExecutor.doExecute2(MojoExecutor.java:328)
        at org.apache.maven.lifecycle.internal.MojoExecutor.doExecute(MojoExecutor.java:316)
        at org.apache.maven.lifecycle.internal.MojoExecutor.execute(MojoExecutor.java:212)
        at org.apache.maven.lifecycle.internal.MojoExecutor.execute(MojoExecutor.java:174)
        at org.apache.maven.lifecycle.internal.MojoExecutor.access$000(MojoExecutor.java:75)
        at org.apache.maven.lifecycle.internal.MojoExecutor$1.run(MojoExecutor.java:162)
        at org.apache.maven.plugin.DefaultMojosExecutionStrategy.execute(DefaultMojosExecutionStrategy.java:39)
        at org.apache.maven.lifecycle.internal.MojoExecutor.execute(MojoExecutor.java:159)
        at org.apache.maven.lifecycle.internal.builder.singlethreaded.SingleThreadedBuilder.build(SingleThreadedBuilder.java:53)
        at org.apache.maven.lifecycle.internal.LifecycleStarter.execute(LifecycleStarter.java:118)
        at org.apache.maven.DefaultMaven.doExecute(DefaultMaven.java:261)
        at org.apache.maven.DefaultMaven.doExecute(DefaultMaven.java:173)
        at org.apache.maven.DefaultMaven.execute(DefaultMaven.java:101)
        at org.apache.maven.cli.MavenCli.execute(MavenCli.java:919)
        at org.apache.maven.cli.MavenCli.doMain(MavenCli.java:285)
        at org.apache.maven.cli.MavenCli.main(MavenCli.java:207)
        at java.base/jdk.internal.reflect.DirectMethodHandleAccessor.invoke(DirectMethodHandleAccessor.java:103)
        at java.base/java.lang.reflect.Method.invoke(Method.java:580)
        at org.codehaus.plexus.classworlds.launcher.Launcher.launchEnhanced(Launcher.java:255)
        at org.codehaus.plexus.classworlds.launcher.Launcher.launch(Launcher.java:201)
        at org.codehaus.plexus.classworlds.launcher.Launcher.mainWithExitCode(Launcher.java:361)
        at org.codehaus.plexus.classworlds.launcher.Launcher.main(Launcher.java:314)
```

## Root Cause

Stale compiled class file. `ComprehensiveMatrixIT.java` was deleted from source but its old `.class` file remains in `integration-tests/target/test-classes/`. Surefire reports "Nothing to compile - all classes are up to date" (no source to recompile), then the forked JVM loads the old instrumented bytecode and the verifier rejects it.

## Fix

Run `mvn clean` before `./run-it-ti.sh` to remove stale compiled classes:

```bash
cd /Users/satya/Git/integration-tests-maven
mvn clean
./run-it-ti.sh
```
