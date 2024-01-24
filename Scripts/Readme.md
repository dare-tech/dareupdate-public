If the Zulu JDK release uses "CFBundleVersion" in the Info.plist for the version, use the munki recipe ending in "LTS". If "CFBundleShortVersionString" is used for the version, use the munki recipe without "LTS" at the end.

"ARCHITECTURE" key - "x" for intel, "aarch" for Apple silicon

"MAJORVERSION" key - the major release of Zulu JDK, e.g, 11
