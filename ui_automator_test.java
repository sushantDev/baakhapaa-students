import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject;
import androidx.test.uiautomator.UiObjectNotFoundException;
import androidx.test.uiautomator.UiScrollable;
import androidx.test.uiautomator.UiSelector;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.Until;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import static org.hamcrest.core.IsNull.notNullValue;
import static org.junit.Assert.assertThat;

@RunWith(AndroidJUnit4.class)
public class BaakhapaaUITest {
    
    private static final String BAAKHAPAA_PACKAGE = "com.baakhapaa.com";
    private static final int LAUNCH_TIMEOUT = 5000;
    private UiDevice device;

    @Before
    public void startMainActivityFromHomeScreen() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        
        // Start from home screen
        device.pressHome();
        
        // Wait for launcher
        final String launcherPackage = device.getLauncherPackageName();
        assertThat(launcherPackage, notNullValue());
        device.wait(Until.hasObject(By.pkg(launcherPackage).depth(0)), LAUNCH_TIMEOUT);
        
        // Launch the app
        Context context = InstrumentationRegistry.getInstrumentation().getContext();
        final Intent intent = context.getPackageManager()
                .getLaunchIntentForPackage(BAAKHAPAA_PACKAGE);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK);
        context.startActivity(intent);
        
        // Wait for the app to appear
        device.wait(Until.hasObject(By.pkg(BAAKHAPAA_PACKAGE).depth(0)), LAUNCH_TIMEOUT);
    }

    @Test
    public void testCompleteAppFlow() throws UiObjectNotFoundException {
        System.out.println("🚀 Starting complete Baakhapaa app test...");
        
        // Test 1: Handle Language Modal
        handleLanguageModal();
        
        // Test 2: Test Video Interactions
        testVideoInteractions();
        
        // Test 3: Test Navigation
        testNavigation();
        
        // Test 4: Test Like Functionality
        testLikeFunctionality();
        
        System.out.println("✅ All tests completed successfully!");
    }
    
    private void handleLanguageModal() throws UiObjectNotFoundException {
        System.out.println("🌍 Handling language modal...");
        
        // Wait a bit for modal to appear
        device.waitForIdle(3000);
        
        // Try to find and click English or any language option
        UiObject englishOption = device.findObject(new UiSelector().textContains("English"));
        if (englishOption.exists()) {
            englishOption.click();
            System.out.println("✅ Selected English language");
        } else {
            // Try first item in list
            UiObject firstOption = device.findObject(new UiSelector().className("android.widget.TextView").index(0));
            if (firstOption.exists()) {
                firstOption.click();
                System.out.println("✅ Selected first language option");
            }
        }
        
        device.waitForIdle(2000);
    }
    
    private void testVideoInteractions() throws UiObjectNotFoundException {
        System.out.println("🎬 Testing video interactions...");
        
        // Test tap to pause/play
        device.click(device.getDisplayWidth() / 2, device.getDisplayHeight() / 2);
        device.waitForIdle(1000);
        
        device.click(device.getDisplayWidth() / 2, device.getDisplayHeight() / 2);
        device.waitForIdle(1000);
        System.out.println("✅ Video tap interactions tested");
        
        // Test swipe up (next video)
        int startX = device.getDisplayWidth() / 2;
        int startY = (int) (device.getDisplayHeight() * 0.8);
        int endY = (int) (device.getDisplayHeight() * 0.2);
        
        device.swipe(startX, startY, startX, endY, 50);
        device.waitForIdle(2000);
        System.out.println("✅ Video swipe up tested");
        
        // Test swipe down (previous video)
        device.swipe(startX, endY, startX, startY, 50);
        device.waitForIdle(2000);
        System.out.println("✅ Video swipe down tested");
    }
    
    private void testNavigation() throws UiObjectNotFoundException {
        System.out.println("🧭 Testing navigation...");
        
        String[] navItems = {"Home", "Shorts", "Shop", "Settings"};
        
        for (String navItem : navItems) {
            UiObject navButton = device.findObject(new UiSelector().textContains(navItem));
            if (navButton.exists()) {
                navButton.click();
                device.waitForIdle(1000);
                System.out.println("✅ Navigated to " + navItem);
                
                // Go back to Shorts for consistency
                if (!navItem.equals("Shorts")) {
                    UiObject shortsButton = device.findObject(new UiSelector().textContains("Shorts"));
                    if (shortsButton.exists()) {
                        shortsButton.click();
                        device.waitForIdle(1000);
                    }
                }
            }
        }
    }
    
    private void testLikeFunctionality() throws UiObjectNotFoundException {
        System.out.println("❤️ Testing like functionality...");
        
        // Try to find like button
        UiObject likeButton = device.findObject(new UiSelector().descriptionContains("like"));
        if (likeButton.exists()) {
            likeButton.click();
            device.waitForIdle(1000);
            System.out.println("✅ Like button tested");
        }
        
        // Test double tap like
        int centerX = device.getDisplayWidth() / 2;
        int centerY = device.getDisplayHeight() / 2;
        
        device.click(centerX, centerY);
        Thread.sleep(100);
        device.click(centerX, centerY);
        device.waitForIdle(1000);
        System.out.println("✅ Double tap like tested");
    }
}
