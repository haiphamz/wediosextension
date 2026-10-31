import uuid, os

def make_id():
    return uuid.uuid4().hex[:24].upper()

proj_dir = 'f:/App/scl/ExtensionBrowser/ExtensionBrowser.xcodeproj'
os.makedirs(proj_dir, exist_ok=True)

# Generate stable IDs
id_project = make_id()
id_target = make_id()
id_config_list_proj = make_id()
id_config_list_target = make_id()
id_debug_proj = make_id()
id_release_proj = make_id()
id_debug_target = make_id()
id_release_target = make_id()

id_sources_phase = make_id()
id_resources_phase = make_id()
id_frameworks_phase = make_id()
id_product = make_id()
id_main_group = make_id()
id_products_group = make_id()

swift_files = [
    'App/ExtensionBrowserApp.swift',
    'Core/WebExtensionModel.swift',
    'Core/MatchPattern.swift',
    'Core/ZipExtractor.swift',
    'Core/WebExtensionManager.swift',
    'Core/WebExtensionBridge.swift',
    'Views/BrowserWebView.swift',
    'Views/ExtensionPopupView.swift',
    'Views/ExtensionManagerView.swift',
    'Views/ContentView.swift'
]

resource_files = [
    'App/Info.plist',
    'Resources/Assets.xcassets',
    'Resources/extension_bridge.js',
    'Resources/soundcloud_cue'
]

file_refs = {}
build_files = {}

for f in swift_files + resource_files:
    f_id = make_id()
    b_id = make_id()
    file_refs[f] = f_id
    build_files[f] = b_id

pbx_objects = []

for path, fid in file_refs.items():
    name = os.path.basename(path)
    ext = os.path.splitext(name)[1].lower()
    last_type = 'sourcecode.swift'
    if ext == '.plist': last_type = 'text.plist.xml'
    elif ext == '.xcassets': last_type = 'folder.assetcatalog'
    elif ext == '.js': last_type = 'sourcecode.javascript'
    elif ext == '': last_type = 'folder'
    
    pbx_objects.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {last_type}; path = "{name}"; sourceTree = "<group>"; }};')

pbx_objects.append(f'\t\t{id_product} /* ExtensionBrowser.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ExtensionBrowser.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

for f in swift_files:
    fid = file_refs[f]
    bid = build_files[f]
    name = os.path.basename(f)
    pbx_objects.append(f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

for f in resource_files:
    fid = file_refs[f]
    bid = build_files[f]
    name = os.path.basename(f)
    pbx_objects.append(f'\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

sources_entries = '\n'.join([f'\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */,' for f in swift_files])
resources_entries = '\n'.join([f'\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Resources */,' for f in resource_files])

pbx_objects.append(f'''\t\t{id_sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_entries}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{resources_entries}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};''')

id_app_grp = make_id()
id_core_grp = make_id()
id_views_grp = make_id()
id_res_grp = make_id()

app_children = '\n'.join([f'\t\t\t\t{file_refs[f]} /* {os.path.basename(f)} */,' for f in ['App/ExtensionBrowserApp.swift', 'App/Info.plist']])
core_children = '\n'.join([f'\t\t\t\t{file_refs[f]} /* {os.path.basename(f)} */,' for f in swift_files if f.startswith('Core/')])
views_children = '\n'.join([f'\t\t\t\t{file_refs[f]} /* {os.path.basename(f)} */,' for f in swift_files if f.startswith('Views/')])
res_children = '\n'.join([f'\t\t\t\t{file_refs[f]} /* {os.path.basename(f)} */,' for f in resource_files if not f.startswith('App/')])

pbx_objects.append(f'''\t\t{id_app_grp} /* App */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{app_children}
\t\t\t);
\t\t\tpath = App;
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_core_grp} /* Core */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{core_children}
\t\t\t);
\t\t\tpath = Core;
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_core_grp} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{views_children}
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_res_grp} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{res_children}
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};''')

id_src_root_grp = make_id()
pbx_objects.append(f'''\t\t{id_src_root_grp} /* ExtensionBrowser */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{id_app_grp} /* App */,
\t\t\t\t{id_core_grp} /* Core */,
\t\t\t\t{id_views_grp} /* Views */,
\t\t\t\t{id_res_grp} /* Resources */,
\t\t\t);
\t\t\tpath = ExtensionBrowser;
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_products_group} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{id_product} /* ExtensionBrowser.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{id_src_root_grp} /* ExtensionBrowser */,
\t\t\t\t{id_products_group} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_target} /* ExtensionBrowser */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {id_config_list_target} /* Build configuration list for PBXNativeTarget "ExtensionBrowser" */;
\t\t\tbuildPhases = (
\t\t\t\t{id_sources_phase} /* Sources */,
\t\t\t\t{id_frameworks_phase} /* Frameworks */,
\t\t\t\t{id_resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ExtensionBrowser;
\t\t\tproductName = ExtensionBrowser;
\t\t\tproductReference = {id_product} /* ExtensionBrowser.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};''')

pbx_objects.append(f'''\t\t{id_project} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{id_target} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {id_config_list_proj} /* Build configuration list for PBXProject "ExtensionBrowser" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {id_main_group};
\t\t\tproductRefGroup = {id_products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{id_target} /* ExtensionBrowser */,
\t\t\t);
\t\t}};''')

# Build settings with Code Signing DISABLED completely (for unsigned ad-hoc builds)
common_settings = '''
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCODE_SIGNING_REQUIRED = NO;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = ExtensionBrowser/App/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.vanhai.extensionbrowser;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
'''

pbx_objects.append(f'''\t\t{id_debug_proj} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{common_settings}
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_release_proj} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{common_settings}
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t}};
\t\t\tname = Release;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_debug_target} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{common_settings}
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_release_target} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{common_settings}
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t}};
\t\t\tname = Release;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_config_list_proj} /* Build configuration list for PBXProject "ExtensionBrowser" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{id_debug_proj} /* Debug */,
\t\t\t\t{id_release_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')

pbx_objects.append(f'''\t\t{id_config_list_target} /* Build configuration list for PBXNativeTarget "ExtensionBrowser" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{id_debug_target} /* Debug */,
\t\t\t\t{id_release_target} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')

all_objects = '\n'.join(pbx_objects)
pbxproj_content = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{
{all_objects}
\t}};
\trootObject = {id_project} /* Project object */;
}}
'''

with open(os.path.join(proj_dir, 'project.pbxproj'), 'w', encoding='utf-8') as f:
    f.write(pbxproj_content)

# CREATE SHARED SCHEME (CRITICAL FOR XCODEBUILD)
scheme_dir = os.path.join(proj_dir, 'xcshareddata', 'xcschemes')
os.makedirs(scheme_dir, exist_ok=True)

scheme_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{id_target}"
               BuildableName = "ExtensionBrowser.app"
               BlueprintName = "ExtensionBrowser"
               ReferencedContainer = "container:ExtensionBrowser.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{id_target}"
            BuildableName = "ExtensionBrowser.app"
            BlueprintName = "ExtensionBrowser"
            ReferencedContainer = "container:ExtensionBrowser.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{id_target}"
            BuildableName = "ExtensionBrowser.app"
            BlueprintName = "ExtensionBrowser"
            ReferencedContainer = "container:ExtensionBrowser.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''

with open(os.path.join(scheme_dir, 'ExtensionBrowser.xcscheme'), 'w', encoding='utf-8') as f:
    f.write(scheme_content)

print('Generated project.pbxproj AND ExtensionBrowser.xcscheme successfully!')
