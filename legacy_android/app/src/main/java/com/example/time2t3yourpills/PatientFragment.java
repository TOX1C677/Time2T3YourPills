package com.example.time2t3yourpills;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import com.example.time2t3yourpills.models.User;
import com.example.time2t3yourpills.repository.UserRepository;

public class PatientFragment extends Fragment {

    private UserViewModel userViewModel;
    private EditText nameEditText;
    private EditText middleNameEditText;
    private EditText notesEditText;
    private User currentUser;  // текущий пользователь

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_patient, container, false);

        initializeViews(view);
        initializeViewModel();

        return view;
    }

    @Override
    public void onResume() {
        super.onResume();
        Bundle args = getArguments();
        if (args != null) {
            int userId = args.getInt("userId", 0);
            if (userId > 0) {
                loadUser(userId);
            }
        }
    }

    private void initializeViews(View view) {
        nameEditText = view.findViewById(R.id.name_edit_text);
        middleNameEditText = view.findViewById(R.id.middle_name_edit_text);
        notesEditText = view.findViewById(R.id.notes_edit_text);
        Button saveButton = view.findViewById(R.id.save_button);

        saveButton.setOnClickListener(v -> {
            saveUser();
        });
    }

    private void initializeViewModel() {
        userViewModel = new ViewModelProvider(this).get(UserViewModel.class);
        userViewModel.getUser().observe(getViewLifecycleOwner(), user -> {
            if (user != null) {
                currentUser = user;
                updateUI(user);
            }
        });
    }

    private void loadUser(int userId) {
        Log.d("PatientFragment", "loadUser called with userId: " + userId);
        userViewModel.getUserById(userId).observe(getViewLifecycleOwner(), user -> {
            if (user != null) {
                currentUser = user;
                updateUI(user);
            }
        });
    }

    private void updateUI(User user) {
        nameEditText.setText(user.getName());
        middleNameEditText.setText(user.getMiddleName());
        notesEditText.setText(user.getNotes());
    }

    private void saveUser() {
        String name = nameEditText.getText().toString().trim();
        String middleName = middleNameEditText.getText().toString().trim();
        String notes = notesEditText.getText().toString().trim();

        if (currentUser == null) {
            currentUser = new User();
        }

        currentUser.setName(name.isEmpty() ? null : name);
        currentUser.setMiddleName(middleName.isEmpty() ? null : middleName);
        currentUser.setNotes(notes.isEmpty() ? null : notes);

        userViewModel.insertOrUpdateUser(currentUser, new UserRepository.DataSaveCallback() {
            @Override
            public void onDataSaved() {
                Log.d("PatientFragment", "Data saved successfully");
            }

            @Override
            public void onDataSaveError(Exception e) {
                Log.e("PatientFragment", "Data save error", e);
            }
        });

        Log.d("PatientFragment", currentUser.getId() > 0 ? "Updating user with ID: " + currentUser.getId() : "Inserting new user");
    }


}
