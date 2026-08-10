/*
  Switches that are not product configuration.
*/

/**
 * Hides every two factor control in this client.
 *
 * Off, and it should stay off: the enrolment screen it used to stand in for
 * now exists, so hiding the controls would leave an admin on a server that
 * requires a second factor with no way to set one up.
 */
export const HIDE_TWO_FACTOR = false;
