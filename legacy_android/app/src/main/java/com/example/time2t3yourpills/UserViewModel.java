package com.example.time2t3yourpills;

import android.app.Application;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.Transformations;
import com.example.time2t3yourpills.models.User;
import com.example.time2t3yourpills.models.Note;
import com.example.time2t3yourpills.repository.UserRepository;
import java.util.List;

public class UserViewModel extends AndroidViewModel {

    private final UserRepository userRepository;
    private LiveData<User> user;
    private LiveData<List<Note>> notes;

    public UserViewModel(@NonNull Application application) {
        super(application);

        userRepository = new UserRepository(application);
        user = userRepository.getUser();
        notes = Transformations.switchMap(user, user -> {
            if (user != null) {
                Log.d("UserViewModel", "User changed: " + user.getId());
                return userRepository.getNotes(user.getId());
            } else {
                Log.d("UserViewModel", "User is null");
                return null;  // или возвращайте пустой список заметок
            }
        });
    }

    public LiveData<User> getUser() {
        return user;
    }

    public LiveData<List<Note>> getNotes() {
        return notes;
    }

    public LiveData<User> getUserById(int userId) {
        return userRepository.getUserById(userId);
    }

    public void insertOrUpdateUser(User user, UserRepository.DataSaveCallback callback) {
        userRepository.insertOrUpdateUser(user, callback);
        Log.d("UserViewModel", "insertOrUpdateUser called");
    }


    // ... другие методы по мере необходимости
}