# Required Mac and iPhone checks — not yet run

- Build with Xcode for both simulator and physical device. Verify launch, portrait and landscape layouts, large text and keyboard access to Settings Save.
- Fresh installation: no prefilled personal name/email. Save all report settings, including a different supported site and custom location. Relaunch and verify persistence.
- Select multiple photos, cancel replacement, then confirm replacement. Verify JPEG preview, ordering, queue counter and that original library photos remain unchanged.
- Use a local test form with the supported field IDs to validate filling, search-based site selection, all edited defaults, receipt on/off and same email behavior. Do not send test reports to the live service.
- Attach the current photo; verify the form displays it and check real upload completion during an authorized actual report. Retry only deliberately; check Browse fallback, missing upload field, an unavailable photo and files over the size limit.
- Go to Submit must only scroll. No click, Enter, requestSubmit or submit call should occur. Verification must remain visible and user-controlled.
- Check genuine WebView verification and login compatibility manually. If the service does not support the flow, use Safari; do not bypass or modify verification.
- Navigate or reload during filling or attachment. Confirm cancellation prevents data from being attached to a different report. Cancel/confirm Next Report; confirm advance never sends a form.
- Check external links, loss of connectivity, settings storage errors and expired server sessions.
- Complete Apple signing, privacy and beta review requirements before distributing through TestFlight.
