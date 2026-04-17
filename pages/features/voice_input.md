# Voice input

You can use your microphone to control the agent. Simply click the microphone icon, close to the send button, and start dictating.

<iframe width="640" height="360" src="https://www.youtube.com/embed/nTthyHCzj-g?si=6B8gTK5o_S5j2CKY" title="Tidewave Voice Input" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Browser considerations

Note the voice input is fully controlled by your browser, which implies:

* The browser uses your default microphone. You can change which microphone to use either in your browser settings or in your Operating System.

* The browser uses your default language. You can configure your default language in your browser settings.

* The browser may use remote services for speech recognition. Some browsers (typically Chromium based browsers like Chrome, Edge, etc.) offer the ability to perform on-device recognition for certain languages. You can choose this option in Tidewave settings (see below).

* Not all browsers have speech recognition available. In such cases, you will see an error message such as "Voice input failed: network error. Try enabling on-device recognition in Settings".

## On-device recognition

For browsers that do not provide remote speech recognition services or for privacy reasons, you may opt into on-device recognition, as long as your browser supports it.

To enable it, open up Tidewave Settings and find the "Voice input recognition" label:

<img src="assets/voice-input-settings.png" alt="Voice input settings" width="600">

And choose "On-device" instead of "Default". Once selected, the relevant language pack will be installed locally. If your browser does not support "On-device" recognition, the option will be disabled.

## Tips

Here are some useful tips for making the best of voice input:

* While using the voice input, you can still use the [Inspector](inspector.md) or click on lines during [Code Review](code_review.md), and Tidewave should correctly inject them as part of your speech. However, some browsers require you to briefly pause before clicking.

* Use `Ctrl+Shift+M` (or `Cmd+Shift+M` on macOS) to quickly toggle voice input.
