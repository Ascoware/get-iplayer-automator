-- GetFireFoxURL.applescript
-- Get_iPlayer GUI

--  Created by Thomas Willson on 8/7/09.
--  Copyright 2009 __MyCompanyName__. All rights reserved.
try
	tell application "Firefox"
		set myURL to «class curl» of window 1
	end tell
on error
	set myURL to "Error"
end try
return myURL as string
