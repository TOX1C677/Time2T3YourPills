package com.example.time2t3yourpills;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;

public class AboutFragment extends Fragment {

    private SharedViewModel sharedViewModel;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_about, container, false);

        // Get the SharedViewModel instance
        sharedViewModel = new ViewModelProvider(requireActivity()).get(SharedViewModel.class);

        TextView appNameTextView = view.findViewById(R.id.app_name_text_view);
        TextView appVersionTextView = view.findViewById(R.id.app_version_text_view);
        TextView contactInfoTextView = view.findViewById(R.id.contact_info_text_view);

        appNameTextView.setText(getString(R.string.app_name));
        appVersionTextView.setText(getString(R.string.app_version, "1.0"));
        contactInfoTextView.setText(getString(R.string.contact_info, "your_email@example.com"));

        return view;
    }
}
