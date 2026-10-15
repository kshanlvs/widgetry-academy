// Where the Widgetry Jobs server lives. The academy stays on Firebase; the jobs server is hosted separately.
// Local testing (localhost) uses the same origin.
const LIVE = "https://api.widgetryacademy.in/api";
export const JOBS_API = /^(localhost|127\.0\.0\.1)$/.test(location.hostname) ? "/api" : LIVE;
