package com.example.time2t3yourpills.dao;

import android.os.AsyncTask;
import android.util.Log;
import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Transaction;
import androidx.room.Update;
import com.example.time2t3yourpills.models.User;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

@Dao
public interface UserDao {
    Executor executor = Executors.newSingleThreadExecutor();

    // Insert a new user into the database
    @Insert
    void insert(User user);

    // Get a user synchronously (not recommended on the main thread)
    @Query("SELECT * FROM user_table LIMIT 1")
    User getUserSync();

    // Get a user asynchronously (safe for main thread)
    @Query("SELECT * FROM user_table LIMIT 1")
    LiveData<User> getUserAsync();

    // Get a user by ID asynchronously (safe for main thread)
    @Query("SELECT * FROM user_table WHERE id = :userId")
    LiveData<User> getUserById(int userId);

    // Get all users asynchronously (safe for main thread)
    @Query("SELECT * FROM user_table")
    LiveData<List<User>> getAllUsers();

    // Update an existing user
    @Update
    void update(User user);

    // Delete a user by ID
    @Query("DELETE FROM user_table WHERE id = :userId")
    void deleteUser(int userId);

    // Insert or update a user, preserving the existing ID if it exists
    @Transaction
    default void insertOrUpdate(User user) {
        executor.execute(() -> {
            try {
                User existingUser = getUserSync();
                if (existingUser == null) {
                    insert(user);
                } else {
                    user.setId(existingUser.getId());  // Preserve the existing ID
                    update(user);
                }
                Log.d("UserDao", "Successfully inserted or updated user");
            } catch (Exception e) {
                Log.e("UserDao", "Error inserting or updating user", e);
            }
        });
    }

    // Delete a user asynchronously
    default void deleteUserAsync(int userId) {
        AsyncTask.execute(() -> {
            try {
                deleteUser(userId);
                Log.d("UserDao", "Successfully deleted user with ID: " + userId);
            } catch (Exception e) {
                Log.e("UserDao", "Error deleting user with ID: " + userId, e);
            }
        });
    }
    // ... Other queries as needed
}
