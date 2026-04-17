/* ios_config.h — forced-included by Xcode build setting
 * Defines platform constants before any zork C files are compiled. */

#ifndef IOS_CONFIG_H
#define IOS_CONFIG_H

/* Use the filename in the current working directory (Documents/) */
#define TEXTFILE      "dtextc.dat"
#define LOCALTEXTFILE "dtextc.dat"

/* Disable the terminal pager — we handle scrolling in SwiftUI */
#define MORE_NONE 1

/* Identify as unix so local.c / supp.c pick up the right paths */
#ifndef unix
#define unix 1
#endif

#endif /* IOS_CONFIG_H */
