//
/* You may copy+paste this file and use it as it is.
 *
 * If you make changes to your about:config while the program is running, the
 * changes will be overwritten by the user.js when the application restarts.
 *
 * To make lasting changes to preferences, you will have to edit the user.js.
 */

/****************************************************************************
 * Betterfox                                                                *
 * "Ad meliora"                                                             *
 * version: 122                                                             *
 * url: https://github.com/yokoffing/Betterfox                              *
****************************************************************************/

/****************************************************************************
 * SECTION: FASTFOX                                                         *
****************************************************************************/
/** GENERAL ***/
user_pref("nglayout.initialpaint.delay", 1000); // DEFAULT; formerly 250
user_pref("nglayout.initialpaint.delay_in_oopif", 1000); // DEFAULT
user_pref("content.notify.interval", 100000);

/** GFX ***/
user_pref("gfx.canvas.accelerated.cache-items", 4096);
user_pref("gfx.canvas.accelerated.cache-size", 512);
user_pref("gfx.content.skia-font-cache-size", 20);

/** DISK CACHE ***/
user_pref("browser.cache.jsbc_compression_level", 3);

/** MEDIA CACHE ***/
user_pref("media.memory_cache_max_size", 65536);
user_pref("media.cache_readahead_limit", 7200);
user_pref("media.cache_resume_threshold", 3600);

/** IMAGE CACHE ***/
user_pref("image.mem.decode_bytes_at_a_time", 32768);

/** NETWORK ***/
user_pref("network.buffer.cache.size", 262144);
user_pref("network.buffer.cache.count", 128);
user_pref("network.http.max-connections", 1800);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.dnsCacheExpiration", 3600);
user_pref("network.dns.max_high_priority_threads", 8);
user_pref("network.ssl_tokens_cache_capacity", 10240);

/** SPECULATIVE LOADING ***/
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.predictor.enabled", false);

/** EXPERIMENTAL ***/
user_pref("layout.css.grid-template-masonry-value.enabled", true);
user_pref("dom.enable_web_task_scheduling", true);
user_pref("layout.css.has-selector.enabled", true);
user_pref("dom.security.sanitizer.enabled", true);

/****************************************************************************************
 * Smoothfox                                                                            *
 * "Faber est suae quisque fortunae"                                                    *
 * priority: better scrolling                                                           *
 * version: 8 January 2024                                                              *
 * url: https://github.com/yokoffing/Betterfox                                          *
 ***************************************************************************************/

// Note: msdPhysics was enabled by default for 122 Nightly.
// The options below have not been modified to account for this change.
// [1] https://bugzilla.mozilla.org/show_bug.cgi?id=1846935

// Use only one option at a time!
// Reset prefs if you decide to use different option.

/****************************************************************************************
 * OPTION: SHARPEN SCROLLING                                                           *
****************************************************************************************/
// credit: https://github.com/black7375/Firefox-UI-Fix
// only sharpen scrolling
// user_pref("apz.overscroll.enabled", true); // DEFAULT NON-LINUX
user_pref("mousewheel.min_line_scroll_amount", 40); // 10-40; adjust this number to your liking; default=5
// user_pref("general.smoothScroll.mouseWheel.durationMinMS", 80); // default=50
// user_pref("general.smoothScroll.currentVelocityWeighting", "0.15"); // default=.25
// user_pref("general.smoothScroll.stopDecelerationWeighting", "0.6"); // default=.4

/****************************************************************************************
 * OPTION: INSTANT SCROLLING (SIMPLE ADJUSTMENT)                                       *
****************************************************************************************/
// recommended for 60hz+ displays
user_pref("apz.overscroll.enabled", true); // DEFAULT NON-LINUX
user_pref("general.smoothScroll", true); // DEFAULT
user_pref("mousewheel.default.delta_multiplier_y", 99); // 250-400; adjust this number to your liking

/****************************************************************************************
 * OPTION: SMOOTH SCROLLING                                                            *
****************************************************************************************/
// recommended for 90hz+ displays
// user_pref("apz.overscroll.enabled", true); // DEFAULT NON-LINUX
// user_pref("general.smoothScroll", true); // DEFAULT
// user_pref("general.smoothScroll.msdPhysics.enabled", true);
// user_pref("mousewheel.default.delta_multiplier_y", 300); // 250-400; adjust this number to your liking

/****************************************************************************************
 * OPTION: NATURAL SMOOTH SCROLLING V3 [MODIFIED]                                      *
****************************************************************************************/
// credit: https://github.com/AveYo/fox/blob/cf56d1194f4e5958169f9cf335cd175daa48d349/Natural%20Smooth%20Scrolling%20for%20user.js
// recommended for 120hz+ displays
// largely matches Chrome flags: Windows Scrolling Personality and Smooth Scrolling
// user_pref("apz.overscroll.enabled", true); // DEFAULT NON-LINUX
// user_pref("general.smoothScroll", true); // DEFAULT
// user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 12);
// user_pref("general.smoothScroll.msdPhysics.enabled", true);
// user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
// user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 650);
// user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 25);
// user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaRatio", 2.0);
// user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 250);
// user_pref("general.smoothScroll.currentVelocityWeighting", 1.0);
// user_pref("general.smoothScroll.stopDecelerationWeighting", 1.0);
// user_pref("mousewheel.default.delta_multiplier_y", 300); // 250-400; adjust this number to your liking
