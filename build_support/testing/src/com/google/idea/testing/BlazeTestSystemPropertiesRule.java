/*
 * Copyright 2016 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.idea.testing;

import com.google.common.base.Joiner;
import com.google.common.collect.Lists;
import com.google.common.io.Files;
import com.intellij.ide.plugins.PluginManagerCore;
import com.intellij.openapi.application.Application;
import com.intellij.openapi.application.PathManager;
import com.intellij.openapi.vfs.newvfs.impl.VfsRootAccess;
import com.intellij.util.PlatformUtils;
import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Enumeration;
import java.util.List;
import javax.annotation.Nullable;
import org.junit.rules.ExternalResource;

/**
 * Test utilities specific to running IntelliJ integration tests in a blaze/bazel environment.
 * Should be instantiated as a @ClassRule in the outermost test class/suite.
 */
public class BlazeTestSystemPropertiesRule extends ExternalResource {

  @Override
  protected void before() throws Throwable {
    configureSystemProperties();
  }

  /** The absolute path to the runfiles directory. */
  private static final String RUNFILES_PATH = TestUtils.getUserValue("TEST_SRCDIR");

  /** Sets up the necessary system properties for running IntelliJ tests via blaze/bazel. */
  private static void configureSystemProperties() throws IOException {
    File sandbox = new File(TestUtils.getTmpDirFile(), "_intellij_test_sandbox");

    setSandboxPath("idea.home.path", new File(sandbox, "home"));
    setSandboxPath("idea.config.path", new File(sandbox, "config"));
    setSandboxPath("idea.system.path", new File(sandbox, "system"));

    setSandboxPath("java.util.prefs.userRoot", new File(sandbox, "userRoot"));
    setSandboxPath("java.util.prefs.systemRoot", new File(sandbox, "systemRoot"));

    setIfEmpty("idea.classpath.index.enabled", "false");

    // Some plugins have a since-build and until-build restriction, so we need
    // to update the build number here
    PluginManagerCore.BUILD_NUMBER = readApiVersionNumber();

    setIfEmpty(
            PlatformUtils.PLATFORM_PREFIX_KEY, determinePlatformPrefix(PluginManagerCore.BUILD_NUMBER));

    // Tests fail if they access files outside of the project roots and other system directories.
    // Ensure runfiles and platform api are whitelisted.
    VfsRootAccess.allowRootAccess(RUNFILES_PATH);
    String platformApi = getPlatformApiPath();
    if (platformApi != null) {
      VfsRootAccess.allowRootAccess(platformApi);
    }

    List<String> pluginJars = Lists.newArrayList();
    try {
      Enumeration<URL> urls =
              BlazeTestSystemPropertiesRule.class.getClassLoader().getResources("META-INF/plugin.xml");
      while (urls.hasMoreElements()) {
        URL url = urls.nextElement();
        addArchiveFile(url, pluginJars);
      }
    } catch (IOException e) {
      System.err.println("Cannot find plugin.xml resources");
      e.printStackTrace();
    }

    setIfEmpty("idea.plugins.path", Joiner.on(File.pathSeparator).join(pluginJars));
  }

  @Nullable
  private static String determinePlatformPrefix(String buildNumber) {
    if (buildNumber.startsWith("AI")) { // Android Studio
      return "AndroidStudio";
    } else if (buildNumber.startsWith("IU")) { // IntelliJ Ultimate
      return null;
    } else if (buildNumber.startsWith("IC")) { // IntelliJ Community
      return "Idea";
    } else if (buildNumber.startsWith("CL")) { // CLion
      return "CLion";
    } else {
      throw new RuntimeException("Unable to determine platform prefix for build: " + buildNumber);
    }
  }

  private static String readApiVersionNumber() {
    String apiVersionFilePath = System.getProperty("blaze.idea.api.version.file");
    String runfilesWorkspaceRoot = System.getProperty("user.dir");
    if (apiVersionFilePath == null) {
      throw new RuntimeException("No api_version_file found in runfiles directory");
    }
    if (runfilesWorkspaceRoot == null) {
      throw new RuntimeException("Runfiles workspace root not found");
    }
    File apiVersionFile = new File(runfilesWorkspaceRoot, apiVersionFilePath);
    if (!apiVersionFile.canRead()) {
      return null;
    }
    try {
      return Files.asCharSource(apiVersionFile, StandardCharsets.UTF_8).readFirstLine();
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
  }

  @Nullable
  private static String getPlatformApiPath() {
    String platformJar = PathManager.getJarPathForClass(Application.class);
    if (platformJar == null) {
      return null;
    }
    File jarFile = new File(platformJar).getAbsoluteFile();
    File jarDir = jarFile.getParentFile();
    if (jarDir == null) {
      return null;
    }
    if (jarDir.getName().equals("lib")) {
      // Building against IDE distribution.
      // root/ <- we want this
      // |-lib/
      // | `-openapi.jar (jarFile)
      // `-plugins/
      return jarDir.getParent();
    } else if (jarDir.getName().equals("core-api")) {
      // Building against source.
      // tools/idea/ <- we want this
      // |-platform/
      // | `-core-api/
      // |   `-libcore-api.jar (jarFile)
      // `-plugins/
      File platformDir = jarDir.getParentFile();
      if (platformDir != null && platformDir.getName().equals("platform")) {
        return platformDir.getParent();
      }
    }
    return null;
  }

  private static void addArchiveFile(URL url, List<String> files) {
    if ("jar".equals(url.getProtocol())) {
      String path = url.getPath();
      int index = path.indexOf("!/");
      if (index > 0) {
        String jarPath = path.substring(0, index);
        if (jarPath.startsWith("file:")) {
          files.add(jarPath.substring(5));
        }
      }
    }
  }

  private static void setSandboxPath(String property, File path) {
    path.mkdirs();
    setIfEmpty(property, path.getPath());
  }

  private static void setIfEmpty(String property, @Nullable String value) {
    if (value == null) {
      return;
    }
    if (System.getProperty(property) == null) {
      System.setProperty(property, value);
    }
  }
}