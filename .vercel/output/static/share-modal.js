// Stub — no-op to prevent "Cannot read properties of null" errors
(function () {
  var el = document.getElementById('share-modal');
  if (el) {
    el.addEventListener('close', function () {});
  }
})();
