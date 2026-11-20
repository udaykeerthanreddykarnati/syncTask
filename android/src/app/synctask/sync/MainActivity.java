package app.synctask.sync;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
    private WebView webView;

    public static class JsBridge {
        private final Context context;

        public JsBridge(Context context) {
            this.context = context;
        }

        @JavascriptInterface
        public boolean isNative() {
            return true;
        }

        @JavascriptInterface
        public String getMacHost() {
            SharedPreferences prefs = context.getSharedPreferences("synctask_prefs", Context.MODE_PRIVATE);
            return prefs.getString("mac_host", "");
        }

        @JavascriptInterface
        public void setMacHost(String host) {
            SharedPreferences prefs = context.getSharedPreferences("synctask_prefs", Context.MODE_PRIVATE);
            prefs.edit().putString("mac_host", host != null ? host.trim() : "").apply();
            refreshHomeWidget();
        }

        @JavascriptInterface
        public void refreshHomeWidget() {
            Intent intent = new Intent(context, SyncTaskWidgetProvider.class);
            intent.setAction("app.synctask.sync.ACTION_REFRESH_WIDGET");
            context.sendBroadcast(intent);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        window.setStatusBarColor(Color.parseColor("#000000"));
        window.setNavigationBarColor(Color.parseColor("#000000"));

        webView = new WebView(this);
        webView.setBackgroundColor(Color.parseColor("#000000"));

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setAllowFileAccessFromFileURLs(true);
        settings.setAllowUniversalAccessFromFileURLs(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);

        webView.addJavascriptInterface(new JsBridge(this), "SyncTaskNative");
        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());

        setContentView(webView);
        webView.loadUrl("file:///android_asset/index.html");
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) {
            webView.onResume();
            webView.resumeTimers();
        }
        Intent intent = new Intent(this, SyncTaskWidgetProvider.class);
        intent.setAction("app.synctask.sync.ACTION_REFRESH_WIDGET");
        sendBroadcast(intent);
    }

    @Override
    protected void onPause() {
        if (webView != null) {
            webView.onPause();
            webView.pauseTimers();
        }
        super.onPause();
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
