import "../application";
import { registerOfflineServiceWorker } from "../../pwa/register";

// Base surfaces register the worker only on the origins that serve it. See
// adr/pwa-offline-route-exception.md.
void registerOfflineServiceWorker();
