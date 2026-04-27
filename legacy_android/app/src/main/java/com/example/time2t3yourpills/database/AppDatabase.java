package com.example.time2t3yourpills.database;

import android.content.Context;
import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;

import com.example.time2t3yourpills.dao.MedicationDao;
import com.example.time2t3yourpills.dao.NoteDao;
import com.example.time2t3yourpills.dao.UserDao;
import com.example.time2t3yourpills.models.Medication;
import com.example.time2t3yourpills.models.Note;
import com.example.time2t3yourpills.models.User;

@Database(entities = {Medication.class, User.class, Note.class}, version = 8, exportSchema = false)
public abstract class AppDatabase extends RoomDatabase {

    private static volatile AppDatabase INSTANCE;

    public abstract MedicationDao medicationDao();
    public abstract UserDao userDao();
    public abstract NoteDao noteDao();

    public static AppDatabase getDatabase(final Context context) {
        if (INSTANCE == null) {
            synchronized (AppDatabase.class) {
                if (INSTANCE == null) {
                    INSTANCE = buildDatabaseInstance(context);
                }
            }
        }
        return INSTANCE;
    }

    private static AppDatabase buildDatabaseInstance(Context context) {
        return Room.databaseBuilder(context.getApplicationContext(),
                        AppDatabase.class, "app_database")
                .fallbackToDestructiveMigration()
                .build();
    }

}
