package com.example.time2t3yourpills.repository;

import android.app.Application;
import android.util.Log;
import androidx.lifecycle.LiveData;
import androidx.room.Transaction;

import com.example.time2t3yourpills.database.AppDatabase;
import com.example.time2t3yourpills.dao.NoteDao;
import com.example.time2t3yourpills.dao.UserDao;
import com.example.time2t3yourpills.models.Note;
import com.example.time2t3yourpills.models.User;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

public class UserRepository {

    private UserDao userDao;
    private NoteDao noteDao;  // DAO для заметок
    private LiveData<List<User>> allUsers;
    private LiveData<List<Note>> allNotes;  // LiveData для всех заметок
    private Executor executor;

    public UserRepository(Application application) {
        AppDatabase db = AppDatabase.getDatabase(application);
        userDao = db.userDao();
        noteDao = db.noteDao();  // инициализация DAO для заметок
        allUsers = userDao.getAllUsers();
        allNotes = noteDao.getAllNotes();  // получение всех заметок
        executor = Executors.newSingleThreadExecutor();
    }

    public LiveData<List<User>> getAllUsers() {
        return allUsers;
    }

    public LiveData<User> getUser() {
        return userDao.getUserAsync();
    }

    public LiveData<List<Note>> getNotes(int userId) {
        return noteDao.getNotesForUser(userId);
    }

    public LiveData<User> getUserById(int userId) {
        return userDao.getUserById(userId);
    }
    public interface DataSaveCallback {
        void onDataSaved();
        void onDataSaveError(Exception e);
    }


    @Transaction
    public void insertOrUpdateUser(User user, DataSaveCallback callback) {
        executor.execute(() -> {
            try {
                User existingUser = userDao.getUserSync();
                if (existingUser == null) {
                    Log.d("UserRepository", "inserting new user");
                    userDao.insert(user);
                } else {
                    user.setId(existingUser.getId());
                    Log.d("UserRepository", "updating existing user with ID: " + existingUser.getId());
                    userDao.update(user);
                }
                callback.onDataSaved();  // обратите внимание, что callback теперь доступен
            } catch (Exception e) {
                Log.e("UserRepository", "Error inserting or updating user", e);
                callback.onDataSaveError(e);  // обратите внимание, что callback теперь доступен
            }
        });
    }




    public void insertOrUpdateNote(Note note) {  // метод для вставки или обновления заметки
        executor.execute(() -> {
            Note existingNote = noteDao.getNoteSync(note.getId());
            if (existingNote == null) {
                Log.d("UserRepository", "inserting new note");
                noteDao.insert(note);
            } else {
                Log.d("UserRepository", "updating existing note with ID: " + existingNote.getId());
                noteDao.update(note);
            }
        });
    }
}
