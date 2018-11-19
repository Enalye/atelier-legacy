/**
Grimoire
Copyright (c) 2017 Enalye

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising
from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute
it freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented;
	   you must not claim that you wrote the original software.
	   If you use this software in a product, an acknowledgment
	   in the product documentation would be appreciated but
	   is not required.

	2. Altered source versions must be plainly marked as such,
	   and must not be misrepresented as being the original software.

	3. This notice may not be removed or altered from any source distribution.
*/

module atelier.ui.info;

import atelier.core;

import atelier.ui.gui_modal;
import atelier.ui.label;
/+
void setInfoWindow(string title, string information) {
	setModalWindow(new InfoWindow(title, information));
}

void setInfoWindow(string information) {
	setModalWindow(new InfoWindow(information));
}


class InfoWindow: ModalWindow {
	this(string title, string information) {
		super(title, Vec2f.zero);
		auto label = new Label(information);
		size = label.size;
		layout.addChildGui(label);
	}

	this(string information) {
		this("Information", information);
	}
}+/