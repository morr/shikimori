// do not remove. a lot of errors in old browsers otherwise (windows phone browser for example)
require('core-js/stable');
require('regenerator-runtime/runtime');

// must be require to prevent bugs with load order
window.$ = require('jquery'); // eslint-disable-line import/newline-after-import
window.jQuery = window.$;

import sugar from 'vendor/sugar'; // eslint-disable-line import/newline-after-import
sugar.extend();

require('application');
require('turbolinks_load');
require('turbolinks_before_cache');
