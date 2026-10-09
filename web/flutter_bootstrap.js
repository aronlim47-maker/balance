{{flutter_js}}
{{flutter_build_config}}

function showStartupFailure() {
  const message = document.getElementById('balance-loading-message');
  if (message) {
    message.textContent = 'Balance could not load. Check your connection and reload this page.';
  }
}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('balance-loading')?.remove();
    } catch (_) {
      showStartupFailure();
    }
  }
}).catch(showStartupFailure);
