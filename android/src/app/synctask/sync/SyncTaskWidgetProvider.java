package app.synctask.sync;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;

public class SyncTaskWidgetProvider extends AppWidgetProvider {

    public static class FetchWorker implements Runnable {
        private final Context context;
        private final AppWidgetManager mgr;
        private final int widgetId;
        private final RemoteViews views;

        public FetchWorker(Context context, AppWidgetManager mgr, int widgetId, RemoteViews views) {
            this.context = context;
            this.mgr = mgr;
            this.widgetId = widgetId;
            this.views = views;
        }

        @Override
        public void run() {
            HttpURLConnection conn = null;
            try {
                SharedPreferences prefs = context.getSharedPreferences("synctask_prefs", Context.MODE_PRIVATE);
                String syncKey = prefs.getString("mac_host", "");
                if (syncKey == null || syncKey.isEmpty()) {
                    views.setTextViewText(R.id.widget_badge, "Setup");
                    views.setTextViewText(R.id.widget_items, "Tap to set Sync Key in synctask");
                    mgr.updateAppWidget(widgetId, views);
                    return;
                }

                String encodedKey = URLEncoder.encode(syncKey.trim(), "UTF-8");
                URL url = new URL("https://ntfy.sh/" + encodedKey + "/raw?poll=1&since=all");
                conn = (HttpURLConnection) url.openConnection();
                conn.setConnectTimeout(4000);
                conn.setReadTimeout(4000);
                if (conn.getResponseCode() != 200) {
                    return;
                }

                String lastJsonLine = null;
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        String trimmed = line.trim();
                        if (trimmed.startsWith("{") && trimmed.contains("\"reminders\"")) {
                            lastJsonLine = trimmed;
                        }
                    }
                }

                if (lastJsonLine == null) {
                    return;
                }
                JSONObject json = new JSONObject(lastJsonLine);
                JSONArray arr = json.optJSONArray("reminders");
                StringBuilder display = new StringBuilder();
                int activeCount = 0;

                if (arr != null) {
                    for (int i = 0; i < arr.length(); i++) {
                        JSONObject item = arr.getJSONObject(i);
                        if (!item.optBoolean("isDeleted", false) && !item.optBoolean("isCompleted", false)) {
                            activeCount++;
                            boolean starred = item.optBoolean("isStarred", false);
                            if (display.length() > 0) display.append("\n");
                            display.append(starred ? "* " : "- ").append(item.optString("title", ""));
                        }
                    }
                }

                views.setTextViewText(R.id.widget_badge, activeCount + " Active");
                views.setTextViewText(R.id.widget_items,
                        activeCount > 0 ? display.toString() : "All tasks completed. Tap to add.");
                mgr.updateAppWidget(widgetId, views);
            } catch (Exception ignored) {
            } finally {
                if (conn != null) conn.disconnect();
            }
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if ("app.synctask.sync.ACTION_REFRESH_WIDGET".equals(intent.getAction())) {
            AppWidgetManager mgr = AppWidgetManager.getInstance(context);
            int[] ids = mgr.getAppWidgetIds(new ComponentName(context, SyncTaskWidgetProvider.class));
            onUpdate(context, mgr, ids);
        }
    }

    @Override
    public void onUpdate(final Context context, final AppWidgetManager appWidgetManager, final int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateSingleWidget(final Context context, final AppWidgetManager mgr, final int widgetId) {
        final RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_layout);

        Intent launchIntent = new Intent(context, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent);
        views.setOnClickPendingIntent(R.id.widget_items, pendingIntent);

        Intent refreshIntent = new Intent(context, SyncTaskWidgetProvider.class);
        refreshIntent.setAction("app.synctask.sync.ACTION_REFRESH_WIDGET");
        PendingIntent refreshPending = PendingIntent.getBroadcast(
                context, 1, refreshIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_badge, refreshPending);

        mgr.updateAppWidget(widgetId, views);
        new Thread(new FetchWorker(context.getApplicationContext(), mgr, widgetId, views)).start();
    }
}
