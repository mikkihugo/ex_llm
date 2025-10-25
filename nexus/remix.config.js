/** @type {import('@remix-run/dev').AppConfig} */
export default {
  ignoredRouteFiles: ['**/*.css', '**/*.test.{js,jsx,ts,tsx}'],
  server: './src/server.ts',
  serverModuleFormat: 'esm',
};
