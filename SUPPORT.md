# Support & recovery

Koru is a self-binding tool, so the most common support request is **"I locked
myself out — how do I get back in?"** This page is the runbook for that, plus
the refund policy for the optional one-time Koru Pro unlock.

> Honest reminder: Strict Mode is a **deterrent, not an unbreakable lock**
> (Koru is a Device Admin, not a Device Owner). That is exactly why recovery is
> always possible. See [SECURITY.md](SECURITY.md).

## "I'm stuck / Strict Mode won't let me disable it"

Try these in order:

1. **Use your weekly backdoor code.** Open **Koru → Settings → Strict mode**
   and enter the current code to turn Strict Mode off. The code rotates weekly
   and is revealed after a short cooling-off period — that delay is the point.
2. **If Accessibility is off, Strict Mode isn't actually enforcing.** The
   Settings/Recents/uninstall blocking runs through the Accessibility service.
   If it is disabled (or revoked by your OEM / a system update), you can
   uninstall Koru normally from **system Settings → Apps → Koru → Uninstall**.
3. **Last resort — from a computer (USB debugging).** Connect the phone with
   USB debugging enabled and run:

   ```sh
   # If a plain uninstall fails with DELETE_FAILED_DEVICE_POLICY_MANAGER,
   # remove Koru's device-admin first, then uninstall:
   adb shell dpm remove-active-admin com.dev.koru/com.dev.koru.strictmode.KoruDeviceAdminReceiver
   adb shell pm uninstall com.dev.koru
   ```

   A factory reset also removes it, but that wipes the device — use adb instead.

> Uninstalling Koru deletes all its local data (blocklists, stats, intentions).
> Nothing is in the cloud, so there is nothing to restore afterwards.

## "Blocking stopped working"

Most often Android (especially ColorOS/MIUI/Samsung) disabled the Accessibility
service after aggressive battery management. Open Koru — the in-app banner tells
you what is still enforced (app blocking, daily limits, Focus keep running via
the backup service) and what is paused (website blocking, in-app section
blocking, Strict Mode). Tap **Re-enable** to turn Accessibility back on, and
grant **battery optimization: don't optimize** in Settings → Permissions to
reduce future kills.

## Refund policy — Koru Pro (one-time unlock)

> Koru Pro is not built yet; this is the policy that will apply at launch.

- **Within Google Play's automatic window (~48h):** users can self-refund via
  Play. We do not contest these.
- **Beyond the window — refund if:** the paid enforcement genuinely did not
  work on the user's device (e.g. the OEM/AAPM revoked Accessibility and they
  reasonably expected website/in-app/Strict enforcement), or a clear bug
  prevented use. Honor honest dissatisfaction within reason.
- **Decline only for:** obvious abuse (refund-after-extended-use patterns) or
  requests unrelated to the purchase.
- Koru Pro is a **one-time** unlock — there is no recurring charge to cancel.

## Canned responses

**Locked out:**
> Strict Mode is a deterrent, so you can always get back in. Open Koru →
> Settings → Strict mode and enter your weekly backdoor code. If Accessibility
> is already off, Strict Mode isn't enforcing — just uninstall from system
> Settings → Apps → Koru. Full steps: https://github.com/predamatteo/koru/blob/main/SUPPORT.md

**Blocking stopped:**
> Your OEM likely disabled Koru's Accessibility service to save battery. Open
> Koru — the banner shows what's still active vs paused — tap Re-enable, then
> set battery optimization to "don't optimize" for Koru. Details:
> https://github.com/predamatteo/koru/blob/main/SECURITY.md

**"It can be bypassed":**
> Correct — and that's by design. No app can truly prevent its own uninstall
> on Android without enterprise Device Owner mode. Strict Mode adds enough
> friction for an impulse to pass, not to trap you. The honest threat model is
> in SECURITY.md.

**Refund request:**
> Within ~48h you can refund directly through Google Play. Beyond that, if the
> paid features didn't actually work on your device, reply with your device
> model and what failed and we'll sort it out.
