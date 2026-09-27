# R8 keep rules for release builds (Flutter adds this file automatically).
#
# The Google Mobile Ads SDK pulls in WorkManager, which Room instantiates by
# reflection: it loads "<Database>_Impl" by name at app start. Without these
# rules R8 renames/strips the generated classes and the app crashes on launch
# with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class **_Impl { *; }
-keep class androidx.work.impl.** { *; }

# Workers are also created by class name.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
