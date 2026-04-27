package com.example.time2t3yourpills.repository;

        import android.app.Application;
        import android.os.AsyncTask;
        import android.util.Log;

        import androidx.lifecycle.LiveData;

        import com.example.time2t3yourpills.database.AppDatabase;
        import com.example.time2t3yourpills.dao.MedicationDao;
        import com.example.time2t3yourpills.models.Medication;

        import java.util.List;

public class MedicationRepository {

    private MedicationDao medicationDao;
    private LiveData<List<Medication>> allMedications;

    public MedicationRepository(Application application) {
        AppDatabase db = AppDatabase.getDatabase(application);
        medicationDao = db.medicationDao();
        allMedications = medicationDao.getAllMedications();
    }

    public LiveData<List<Medication>> getAllMedications() {
        return allMedications;
    }
    public LiveData<Medication> getMedicationById(String id) {
        // Здесь реализация получения медикамента по ID из вашей базы данных
        // Например, если у вас Room Database:
        return medicationDao.getMedicationById(id);
    }


    public void insert(Medication medication) {
        new InsertAsyncTask(medicationDao).execute(medication);
        Log.d("MedicationRepository", "insert called with medication: " + medication.getName());
    }
    public Medication getMedicationByIdSync(String id) {
        return medicationDao.getMedicationByIdSync(id);
    }

    public void update(Medication medication) {
        new UpdateAsyncTask(medicationDao).execute(medication);
        Log.d("MedicationRepository", "update called with medication: " + medication.getName());
    }

    public void insertOrUpdate(Medication medication) {
        new InsertOrUpdateAsyncTask(medicationDao).execute(medication);
        Log.d("MedicationRepository", "insertOrUpdate called with medication: " + medication.getName());
    }

    private static class UpdateAsyncTask extends AsyncTask<Medication, Void, Void> {
        private MedicationDao asyncTaskDao;

        UpdateAsyncTask(MedicationDao dao) {
            asyncTaskDao = dao;
        }

        @Override
        protected Void doInBackground(final Medication... params) {
            if (params[0] != null) {
                asyncTaskDao.update(params[0]);
                Log.d("UpdateAsyncTask", "Updated medication with ID: " + params[0].getId());
            }
            return null;
        }
    }
    private static class InsertAsyncTask extends AsyncTask<Medication, Void, Void> {

        private MedicationDao asyncTaskDao;

        InsertAsyncTask(MedicationDao dao) {
            asyncTaskDao = dao;
        }

        @Override
        protected Void doInBackground(final Medication... params) {
            if (params[0] != null) {
                long rowId = asyncTaskDao.insert(params[0]);
                Log.d("InsertAsyncTask", "Inserted medication with row ID: " + rowId);
            }
            return null;
        }
    }


    private static class InsertOrUpdateAsyncTask extends AsyncTask<Medication, Void, Void> {
        private MedicationDao asyncTaskDao;

        InsertOrUpdateAsyncTask(MedicationDao dao) {
            asyncTaskDao = dao;
        }

        @Override
        protected Void doInBackground(final Medication... params) {
            if (params[0] != null) {
                Medication existingMedication = asyncTaskDao.getMedicationByIdSync(params[0].getId());
                if (existingMedication == null) {
                    long rowId = asyncTaskDao.insert(params[0]);
                    Log.d("InsertOrUpdateAsyncTask", "Inserted medication with row ID: " + rowId);
                } else {
                    asyncTaskDao.update(params[0]);
                    Log.d("InsertOrUpdateAsyncTask", "Updated existing medication with ID: " + params[0].getId());
                }
            }
            return null;
        }
    }
}