'use strict';

var DEFAULT_SIZE = 100;
var MIN_SECTORS = 3;
var MAX_MENU_ITEMS = 11;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function buildNestedMenu(items, maxItems) {
    if (!Array.isArray(items) || items.length === 0) return [];

    if (items.length <= maxItems) {
        return items.map(function (item) {
            var nextItem = Object.assign({}, item);

            if (Array.isArray(nextItem.items) && nextItem.items.length > 0) {
                nextItem.items = buildNestedMenu(nextItem.items, maxItems);
            }

            return nextItem;
        });
    }

    var visibleItems = items.slice(0, maxItems).map(function (item) {
        var nextItem = Object.assign({}, item);

        if (Array.isArray(nextItem.items) && nextItem.items.length > 0) {
            nextItem.items = buildNestedMenu(nextItem.items, maxItems);
        }

        return nextItem;
    });

    var restItems = items.slice(maxItems).map(function (item) {
        var nextItem = Object.assign({}, item);

        if (Array.isArray(nextItem.items) && nextItem.items.length > 0) {
            nextItem.items = buildNestedMenu(nextItem.items, maxItems);
        }

        return nextItem;
    });

    visibleItems.push({
        id: "_more",
        title: "More",
        icon: "#more",
        items: buildNestedMenu(restItems, maxItems)
    });

    return visibleItems;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function RadialMenu(params) {
    var self = this;
    self.sectorNodes = [];
    self.parent = params.parent || [];
    self.size = params.size || DEFAULT_SIZE;
    self.onClick = params.onClick || null;
    var sourceItems = params.menuItems ? params.menuItems : [{ id: 'one', title: 'One' }, { id: 'two', title: 'Two' }];
    self.menuItems = buildNestedMenu(sourceItems, MAX_MENU_ITEMS);

    self.radius = 50;
    self.innerRadius = self.radius * 0.70;
    self.sectorSpace = self.radius * 0;
    self.sectorCount = Math.max(self.menuItems.length, MIN_SECTORS);
    self.closeOnClick = params.closeOnClick !== undefined ? !!params.closeOnClick : false;
    self.scale = 1;
    self.holder = null;
    self.parentMenu = [];
    self.parentItems = [];
    self.levelItems = null;
    self.transitioning = false;

    self.tiltMax = 9;
    self.selectedLift = 2;

    self.createHolder();
    self.addIconSymbols();

    self.currentMenu = null;
    self.currentCenter = null;
    self.wheelBind = self.onMouseWheel.bind(self);
    self.keyDownBind = self.onKeyDown.bind(self);

    self.mouseMoveBind = self.onMouseMove.bind(self);
    self.pointerAngle = 0;
    self.pointerBeam = null;

    self.mouseUpBind = self.onMouseUp.bind(self);


    self.rafId = null;
    self.lastMouseX = 0;
    self.lastMouseY = 0;
    self.selectedIndex = -1;

    document.addEventListener('wheel', self.wheelBind);
    document.addEventListener('keydown', self.keyDownBind);
    document.addEventListener('mousemove', self.mouseMoveBind);
    document.addEventListener('mouseup', self.mouseUpBind);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.updateByCursor = function (clientX, clientY) {
    var self = this;

    var cx = window.innerWidth / 2;
    var cy = window.innerHeight / 2;

    var dx = clientX - cx;
    var dy = clientY - cy;

    var angle = Math.atan2(dx, dy) * 57.2958;
    if (angle < 0) angle += 360;

    self.pointerAngle = Math.round(angle);

    self.applyMenuPerspectiveByCursor(clientX, clientY);
    self.updatePointerBeamByCursor(clientX, clientY);

    var index = self.getIndexByCursor(clientX, clientY);
    if (index !== -1 && index !== self.selectedIndex) {
        self.setSelectedIndex(index);
    }
};
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.onMouseMove = function (event) {
    var self = this;
    self.lastMouseX = event.clientX;
    self.lastMouseY = event.clientY;

    if (!self.rafId) {
        self.rafId = requestAnimationFrame(function () {
            self.rafId = null;
            self.updateByCursor(self.lastMouseX, self.lastMouseY);
        });
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getIndexByCursor = function (clientX, clientY) {
    var self = this;
    if (!self.levelItems || !self.levelItems.length) return -1;

    var cx = window.innerWidth / 2;
    var cy = window.innerHeight / 2;

    var dx = clientX - cx;
    var dy = clientY - cy;

    var distance = Math.sqrt(dx * dx + dy * dy);

    var pxPerUnit = self.size / 100;
    var outerRadiusPx = self.radius * pxPerUnit;

    var angle = Math.atan2(dx, dy) * (180 / Math.PI);
    if (angle < 0) angle += 360;

    var angleStep = 360 / self.sectorCount;
    var angleShift = angleStep / 2 + 270;
    var indexOffset = self.getIndexOffset();

    var normalized = (angle - angleShift + 360) % 360;
    var rawSector = Math.floor(normalized / angleStep);

    var itemIndex = RadialMenu.resolveLoopIndex(
        self.sectorCount - rawSector + indexOffset,
        self.sectorCount
    );

    if (itemIndex === null || itemIndex < 0 || itemIndex >= self.levelItems.length) {
        return -1;
    }

    return itemIndex;
};

RadialMenu.prototype.updatePointerBeamByCursor = function (clientX, clientY) {
    var self = this;
    if (!self.pointerBeam) return;

    var cx = window.innerWidth / 2;
    var cy = window.innerHeight / 2;

    var dx = clientX - cx;
    var dy = clientY - cy;

    var angle = Math.atan2(dx, dy) * (180 / Math.PI);
    if (angle < 0) angle += 360;

    self.pointerAngle = angle;

    self.pointerBeam.style.transform = 'translate(-50%, 0) rotate(' + -angle + 'deg)';

    var menuHolder = document.getElementById('menuHolder');
    if (menuHolder) {
        menuHolder.style.setProperty('--angle', (-self.pointerAngle) + 'deg');
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.open = function () {
    var self = this;
    if (!self.currentMenu) {
        self.currentMenu = self.createMenu('menu inner', self.menuItems);
        self.holder.appendChild(self.currentMenu);

        // wait DOM commands to apply and then set class to allow transition to take effect
        RadialMenu.nextTick(function () {
            self.currentMenu.setAttribute('class', 'menu');
        });
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.close = function () {
    var self = this;
    self.transitioning = false;
    if (self.currentMenu) {
        var parentMenu;
        while (parentMenu = self.parentMenu.pop()) {
            parentMenu.remove();
        }
        self.parentItems = [];
        $.post(`https://mt_radialmenu/closemenu`, JSON.stringify({}));
        RadialMenu.setClassAndWaitForTransition(self.currentMenu, 'menu inner').then(function () {
            self.currentMenu.remove();
            self.currentMenu = null;
        });
    }
    if (self.pointerBeam) {
    self.pointerBeam.remove();
    self.pointerBeam = null;
}
    if (self.currentCenter) {
        self.currentCenter.remove();
        self.currentCenter = null;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getParentMenu = function () {
    var self = this;
    if (self.parentMenu.length > 0) {
        return self.parentMenu[self.parentMenu.length - 1];
    } else {
        return null;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createHolder = function () {
    var self = this;

    self.holder = document.createElement('div');
    self.holder.id = 'menuHolder';
    self.holder.className = 'menuHolder';
    self.holder.style.width = self.size + 'px';
    self.holder.style.height = self.size + 'px';

    self.parent.appendChild(self.holder);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.showNestedMenu = function (item) {
    var self = this;
    
    var menu = self.currentMenu;
    if (!menu) return;
    
    var sectors = menu.querySelectorAll('g.sector');

    sectors.forEach(function (sector) {
        var baseTransform = sector.getAttribute('data-base-transform');

        if (baseTransform) {
            sector.setAttribute('transform', baseTransform);
        }
    });

    self.parentMenu.push(self.currentMenu);
    self.parentItems.push(self.levelItems);

    self.currentMenu = self.createMenu('menu inner', item.items);
    self.holder.appendChild(self.currentMenu);

    RadialMenu.nextTick(function () {
        self.getParentMenu().setAttribute('class', 'menu outer');
        self.currentMenu.setAttribute('class', 'menu');
    });
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.returnToParentMenu = function () {
    var self = this;

    // handleCenterClick gates this on parentItems.length synchronously, but the
    // stacks below are only popped once the CSS transition finishes. Without this
    // re-entrancy guard, rapid Escape/Backspace/center-clicks queue several returns
    // that each pass that check, then pop past the end of the now-empty stacks ->
    // levelItems becomes undefined and .length throws (RadialMenu.js:300).
    if (self.transitioning) return;
    if (self.parentMenu.length === 0 || self.parentItems.length === 0) return;

    self.transitioning = true;

    self.getParentMenu().setAttribute('class', 'menu');
    RadialMenu.setClassAndWaitForTransition(self.currentMenu, 'menu inner').then(function () {
        self.transitioning = false;

        // A close() (which clears the stacks) may have landed during the transition.
        if (self.parentMenu.length === 0 || self.parentItems.length === 0) return;

        self.currentMenu.remove();
        self.currentMenu = self.parentMenu.pop();
        self.levelItems = self.parentItems.pop();

        self.sectorCount = Math.max(self.levelItems.length, MIN_SECTORS);
        self.scale = self.calcScale();
    });
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.handleClick = function () {
    var self = this;

    var selectedIndex = self.getSelectedIndex();
    if (selectedIndex >= 0) {
        var item = self.levelItems[selectedIndex];
        if (!item) return;
        if (item.items) {
            self.showNestedMenu(item);
        } else {
            if (self.onClick) {
                if (self.closeOnClick) {
                    self.close();
                }
                self.onClick(item);
            }
        }
    }
};

RadialMenu.prototype.onMouseUp = function (event) {
    var self = this;

    if (!self.currentMenu || event.target.closest('.menuCenterAction')) return;
    if (event.button !== 0) return;

    self.handleClick();
};

RadialMenu.prototype.handleCenterClick = function () {
    var self = this;
    if (self.parentItems.length > 0) {
        self.returnToParentMenu();
    } else {
        self.close();
    }
};

RadialMenu.prototype.onKeyDown = function (event) {
    var self = this;
    if (self.currentMenu) {
        switch (event.key) {
            case 'Escape':
            case 'Backspace':
                self.handleCenterClick();
                event.preventDefault();
                break;
            case 'Enter':
                self.handleClick();
                event.preventDefault();
                break;
            case 'ArrowRight':
            case 'ArrowUp':
                self.selectDelta(1);
                event.preventDefault();
                break;
            case 'ArrowLeft':
            case 'ArrowDown':
                self.selectDelta(-1);
                event.preventDefault();
                break;
        }
    }
};
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createCenter = function (options) {
    var self = this;

    options = options || {};
    var title = options.title || '';
    var description = options.description || '';
    var actionType = options.actionType || 'close';
    var actionIcon = options.actionIcon || null;
    var actionLabel = options.actionLabel || (actionType === 'back' ? 'Back' : 'Close');


    if (self.currentCenter) {
        self.currentCenter.remove();
        self.currentCenter = null;
    }

    var center = document.createElement('div');
    center.className = 'menuCenter inner';

    var infoNode = document.createElement('div');
    infoNode.className = 'menuInfo';

    if (title) {
        var titleNode = document.createElement('h2');
        titleNode.className = 'menuInfoTitle';
        titleNode.id = 'menuInfoTitle';
        titleNode.textContent = title;
        infoNode.appendChild(titleNode);
    }

    if (description) {
        var descriptionNode = document.createElement('p');
        descriptionNode.className = 'menuInfoDescription';
        descriptionNode.id = 'menuInfoDescription';
        descriptionNode.textContent = description;
        infoNode.appendChild(descriptionNode);
    }

    center.appendChild(infoNode);

    var actionNode = document.createElement('div');
    actionNode.className = 'menuCenterAction menuCenterAction--' + actionType;

    if (actionIcon) {
        var actionIconNode = document.createElement('div');
        actionIconNode.className = 'menuCenterActionIcon';
        actionIconNode.id = 'menuCenterActionIcon';
        actionIconNode.innerHTML = '<svg viewBox="0 0 41.756 41.756"><use href="' + actionIcon + '"></use></svg>';
        actionNode.appendChild(actionIconNode);
    }

    // var actionTextNode = document.createElement('div');
    // actionTextNode.className = 'menuCenterActionText';
    // actionTextNode.id = 'menuCenterActionText';
    // actionTextNode.textContent = actionLabel;
    // actionNode.appendChild(actionTextNode);

    actionNode.addEventListener('click', function () {
        self.handleCenterClick();
    });

    center.appendChild(actionNode);

    self.holder.appendChild(center);
    self.currentCenter = center;


    RadialMenu.nextTick(function () {
        if (self.currentCenter) {
            self.currentCenter.classList.remove('inner');
        }
    })
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getIndexOffset = function () {
    var self = this;
    if (self.levelItems.length < self.sectorCount) {
        switch (self.levelItems.length) {
            case 1:
                return -2;
            case 2:
                return -2;
            case 3:
                return -2;
            default:
                return -1;
        }
    } else {
        return -1;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createMenu = function (classValue, levelItems) {
    var self = this;

    self.sectorNodes = [];
    self.selectedIndex = -1;
    self.levelItems = levelItems;

    self.sectorCount = Math.max(self.levelItems.length, MIN_SECTORS);
    self.scale = self.calcScale();

    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', classValue);
    svg.setAttribute('viewBox', '-50 -50 100 100');
    svg.setAttribute('width', self.size);
    svg.setAttribute('height', self.size);

    var angleStep = 360 / self.sectorCount;
    var angleShift = angleStep / 2 + 270;

    var indexOffset = self.getIndexOffset();

    for (var i = 0; i < self.sectorCount; ++i) {
        var startAngle = angleShift + angleStep * i;
        var endAngle = angleShift + angleStep * (i + 1);

        var itemIndex = RadialMenu.resolveLoopIndex(self.sectorCount - i + indexOffset, self.sectorCount);
        var item;
        if (itemIndex >= 0 && itemIndex < self.levelItems.length) {
            item = self.levelItems[itemIndex];
        } else {
            item = null;
        }

        self.appendSectorPath(startAngle, endAngle, svg, item, itemIndex);
    }

    self.createPointerBeam(svg);

    self.syncCenter();

    $(svg).on('click', '.center', function (event) {
        self.handleCenterClick();
    });

    return svg;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createPointerBeam = function (svg) {
    var self = this;

    if (self.pointerBeam) {
        self.pointerBeam.remove();
        self.pointerBeam = null;
    }

    var beam = document.createElement('div');

    beam.className = 'pointerBeam';

    beam.innerHTML = `
        <div class="pointerBeamInner"></div>
    `;

    self.holder.appendChild(beam);

    self.pointerBeam = beam;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.selectDelta = function (indexDelta) {
    var self = this;
    var selectedIndex = self.getSelectedIndex();
    if (selectedIndex < 0) {
        selectedIndex = 0;
    }
    selectedIndex += indexDelta;

    if (selectedIndex < 0) {
        selectedIndex = self.levelItems.length + selectedIndex;
    } else if (selectedIndex >= self.levelItems.length) {
        selectedIndex -= self.levelItems.length;
    }
    self.setSelectedIndex(selectedIndex);

    var selectedNode = self.getSelectedNode();
    if (!selectedNode || !selectedNode.lastElementChild) return;

    const rect = selectedNode.lastElementChild.getBoundingClientRect();

    self.updatePointerBeamByCursor(rect.x + 10, rect.y + 10)
    self.applyMenuPerspectiveByCursor(rect.x + 28, rect.y + 28);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.onMouseWheel = function (event) {
    var self = this;
    if (self.currentMenu) {
        var delta = -event.deltaY;

        if (delta > 0) {
            self.selectDelta(1)
        } else {
            self.selectDelta(-1)
        }
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getSelectedNode = function () {
    var self = this;
    if (self.currentMenu) {

        var items = self.currentMenu.getElementsByClassName('selected');
        if (items.length > 0) {
            return items[0];
        } else {
            return null;
        }
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getSelectedIndex = function () {
    var self = this;
    var selectedNode = self.getSelectedNode();
    if (selectedNode) {
        return parseInt(selectedNode.getAttribute('data-index'));
    } else {
        return -1;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.syncCenter = function () {
    var self = this;

    var selectedIndex = self.getSelectedIndex();
    var selectedItem =
        selectedIndex >= 0 && self.levelItems && self.levelItems[selectedIndex]
            ? self.levelItems[selectedIndex]
            : null;

    var actionType = self.getCenterActionType();

    var title = document.getElementById('menuInfoTitle');
    var description = document.getElementById('menuInfoDescription');
    if (selectedItem && title) {
        title.textContent = selectedItem.title ? selectedItem.title : 'Menu';
        if (description) description.textContent = selectedItem.description ? selectedItem.description : '';
    }

    var actionIcon = document.getElementById("menuCenterActionIcon")
    if (actionIcon) {
        actionIcon.innerHTML = '<svg viewBox="0 0 41.756 41.756"><use href="#' + actionType + '"></use></svg>'
    }

    if (!self.currentCenter) {
        self.createCenter({
            title: selectedItem && selectedItem.title ? selectedItem.title : 'Menu',
            description: selectedItem && selectedItem.description ? selectedItem.description : '',
            actionType: actionType,
            actionIcon: actionType === 'back' ? '#back' : '#close',
            actionLabel: actionType === 'back' ? 'Back' : 'Close'
        });
    }
};

RadialMenu.prototype.getCenterActionType = function () {
    return this.parentItems.length > 0 ? 'back' : 'close';
};
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.setSelectedIndex = function (index) {
    var self = this;
    if (index === self.selectedIndex) return;
    if (!self.currentMenu) return;

    if (index >= 0 && index < self.levelItems.length) {
        var items = self.currentMenu.querySelectorAll('g[data-index="' + index + '"]');
        if (items.length > 0) {
            var itemToSelect = items[0];
            var selectedNode = self.getSelectedNode();
            if (selectedNode) {
                selectedNode.setAttribute('class', 'sector');
            }
            itemToSelect.setAttribute('class', 'sector selected');

            self.selectedIndex = index;
        }
    }
    self.updateSelectedElevation();
    self.syncCenter();
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createUseTag = function (x, y, link) {
    var use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('x', RadialMenu.numberToString(x));
    use.setAttribute('y', RadialMenu.numberToString(y));
    use.setAttribute('width', '7');
    use.setAttribute('height', '7');
    use.setAttribute('fill', 'white');
    use.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', link);
    return use;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.appendSectorPath = function (startAngleDeg, endAngleDeg, svg, item, index) {
    var self = this;

    var centerPoint = self.getSectorCenter(startAngleDeg, endAngleDeg);
    var translate = {
        x: RadialMenu.numberToString((1 - self.scale) * centerPoint.x),
        y: RadialMenu.numberToString((1 - self.scale) * centerPoint.y)
    };

    var g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('transform', 'translate(' + translate.x + ' ,' + translate.y + ') scale(' + self.scale + ')');
    g.setAttribute('data-base-transform', 'translate(' + translate.x + ' ,' + translate.y + ') scale(' + self.scale + ')');
    g.setAttribute('data-center-x', centerPoint.x);
    g.setAttribute('data-center-y', centerPoint.y);

    var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', self.createSectorCmds(startAngleDeg, endAngleDeg));
    g.appendChild(path);

    if (item) {
        self.sectorNodes[index] = g;
        g.setAttribute('class', 'sector');
        if (index == 0) {
            g.setAttribute('class', 'sector selected');
        }
        g.setAttribute('data-id', item.id);
        g.setAttribute('data-index', index);

        if (item.icon) {
            var use = self.createUseTag(centerPoint.x, centerPoint.y, item.icon);
            if (item.title) {
                use.setAttribute('transform', 'translate(-4,-4)');
            } else {
                use.setAttribute('transform', 'translate(-5,-5)');
            }

            g.appendChild(use);
        }

    } else {
        g.setAttribute('class', 'dummy');
    }

    svg.appendChild(g);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.createSectorCmds = function (startAngleDeg, endAngleDeg) {
    var self = this;

    var initPoint = RadialMenu.getDegreePos(startAngleDeg, self.radius);
    var path = 'M' + RadialMenu.pointToString(initPoint);

    var radiusAfterScale = self.radius * (1 / self.scale);
    path += 'A' + radiusAfterScale + ' ' + radiusAfterScale + ' 0 0 0' + RadialMenu.pointToString(RadialMenu.getDegreePos(endAngleDeg, self.radius));
    path += 'L' + RadialMenu.pointToString(RadialMenu.getDegreePos(endAngleDeg, self.innerRadius));

    var radiusDiff = self.radius - self.innerRadius;
    var radiusDelta = (radiusDiff - (radiusDiff * self.scale)) / 2;
    var innerRadius = (self.innerRadius + radiusDelta) * (1 / self.scale);
    path += 'A' + innerRadius + ' ' + innerRadius + ' 0 0 1 ' + RadialMenu.pointToString(RadialMenu.getDegreePos(startAngleDeg, self.innerRadius));
    path += 'Z';

    return path;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.calcScale = function () {
    var self = this;
    var totalSpace = self.sectorSpace * self.sectorCount;
    var circleLength = Math.PI * 2 * self.radius;
    var radiusDelta = self.radius - (circleLength - totalSpace) / (Math.PI * 2);
    return (self.radius - radiusDelta) / self.radius;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.getSectorCenter = function (startAngleDeg, endAngleDeg) {
    var self = this;
    return RadialMenu.getDegreePos((startAngleDeg + endAngleDeg) / 2, self.innerRadius + (self.radius - self.innerRadius) / 2);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.prototype.addIconSymbols = function () {
    var self = this;
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'icons');

    // back
    var backSymbol = document.createElementNS('http://www.w3.org/2000/svg', 'symbol');
    backSymbol.setAttribute('id', 'back');
    backSymbol.setAttribute('viewBox', '0 0 489.394 489.394');
    var backPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    backPath.setAttribute('d', "M375.789,92.867H166.864l17.507-42.795c3.724-9.132,1-19.574-6.691-25.744c-7.701-6.166-18.538-6.508-26.639-0.879" +
        "L9.574,121.71c-6.197,4.304-9.795,11.457-9.563,18.995c0.231,7.533,4.261,14.446,10.71,18.359l147.925,89.823" +
        "c8.417,5.108,19.18,4.093,26.481-2.499c7.312-6.591,9.427-17.312,5.219-26.202l-19.443-41.132h204.886" +
        "c15.119,0,27.418,12.536,27.418,27.654v149.852c0,15.118-12.299,27.19-27.418,27.19h-226.74c-20.226,0-36.623,16.396-36.623,36.622" +
        "v12.942c0,20.228,16.397,36.624,36.623,36.624h226.74c62.642,0,113.604-50.732,113.604-113.379V206.709" +
        "C489.395,144.062,438.431,92.867,375.789,92.867z");
    backSymbol.appendChild(backPath);
    svg.appendChild(backSymbol);

    var closeSymbol = document.createElementNS('http://www.w3.org/2000/svg', 'symbol');
    closeSymbol.setAttribute('id', 'close');
    closeSymbol.setAttribute('viewBox', '0 0 41.756 41.756');

    var closePath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    closePath.setAttribute('d', "M27.948,20.878L40.291,8.536c1.953-1.953,1.953-5.119,0-7.071c-1.951-1.952-5.119-1.952-7.07,0L20.878,13.809L8.535,1.465" +
        "c-1.951-1.952-5.119-1.952-7.07,0c-1.953,1.953-1.953,5.119,0,7.071l12.342,12.342L1.465,33.22c-1.953,1.953-1.953,5.119,0,7.071" +
        "C2.44,41.268,3.721,41.755,5,41.755c1.278,0,2.56-0.487,3.535-1.464l12.343-12.342l12.343,12.343" +
        "c0.976,0.977,2.256,1.464,3.535,1.464s2.56-0.487,3.535-1.464c1.953-1.953,1.953-5.119,0-7.071L27.948,20.878z");
    closeSymbol.appendChild(closePath);
    svg.appendChild(closeSymbol);

    self.holder.appendChild(svg);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.getDegreePos = function (angleDeg, length) {
    return {
        x: Math.sin(RadialMenu.degToRad(angleDeg)) * length,
        y: Math.cos(RadialMenu.degToRad(angleDeg)) * length
    };
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.pointToString = function (point) {
    return RadialMenu.numberToString(point.x) + ' ' + RadialMenu.numberToString(point.y);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.numberToString = function (n) {
    if (Number.isInteger(n)) {
        return n.toString();
    } else if (n) {
        var r = (+n).toFixed(5);
        if (r.match(/\./)) {
            r = r.replace(/\.?0+$/, '');
        }
        return r;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.resolveLoopIndex = function (index, length) {
    if (index < 0) {
        index = length + index;
    }
    if (index >= length) {
        index = index - length;
    }
    if (index < length) {
        return index;
    } else {
        return null;
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.degToRad = function (deg) {
    return deg * (Math.PI / 180);
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.setClassAndWaitForTransition = function (node, newClass) {
    return new Promise(function (resolve) {
        function handler(event) {
            if (event.target == node && event.propertyName == 'visibility') {
                node.removeEventListener('transitionend', handler);
                resolve();
            }
        }
        node.addEventListener('transitionend', handler);
        node.setAttribute('class', newClass);
    });
};

RadialMenu.prototype.destroy = function () {
    document.removeEventListener('mousemove', this.mouseMoveBind);
    document.removeEventListener('wheel', this.wheelBind);
    document.removeEventListener('keydown', this.keyDownBind);
    document.removeEventListener('mouseup', this.mouseUpBind);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
RadialMenu.nextTick = function (fn) {
    setTimeout(fn, 10);
};



RadialMenu.prototype.applyMenuPerspectiveByCursor = function (clientX, clientY) {
    var self = this;
    if (!self.currentMenu) return;

    var menuHolder = document.getElementById("menuHolder")
    if(!menuHolder) return;

    var cx = window.innerWidth / 2;
    var cy = window.innerHeight / 2;

    var dx = clientX - cx;
    var dy = clientY - cy;

    var maxDistance = Math.min(window.innerWidth, window.innerHeight) / 2;
    var nx = Math.max(-1, Math.min(1, dx / maxDistance));
    var ny = Math.max(-1, Math.min(1, dy / maxDistance));

    var rotateY = nx * self.tiltMax;
    var rotateX = -ny * self.tiltMax;

    self.currentMenu.style.transformOrigin = '50% 50%';
    self.currentMenu.style.transformBox = 'fill-box';
    self.currentMenu.style.transform =
        'perspective(900px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg)';

    // currentCenter is nulled synchronously by close() while the menu node lingers
    // through its transition, so a mousemove mid-close would otherwise NPE here.
    if (self.currentCenter) {
        self.currentCenter.style.transformOrigin = 'top left';
        self.currentCenter.style.transform =
            'perspective(900px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg) translate(-50%, -50%)';
    }

    menuHolder.style.transformOrigin = '50% 50%';
    menuHolder.style.transformBox = 'fill-box';
    menuHolder.style.transform =
        'perspective(900px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg)';
};

RadialMenu.prototype.updateSelectedElevation = function () {
    var self = this;

    if (!self.currentMenu) return;

    var sectors = self.currentMenu.querySelectorAll('g.sector');

    sectors.forEach(function (sector) {
        var baseTransform = sector.getAttribute('data-base-transform') || '';

        if (!sector.classList.contains('selected')) {
            sector.setAttribute('transform', baseTransform);
            return;
        }

        var cx = parseFloat(sector.getAttribute('data-center-x')) || 0;
        var cy = parseFloat(sector.getAttribute('data-center-y')) || 0;

        var length = Math.sqrt(cx * cx + cy * cy) || 1;

        var liftX = Math.round((cx / length) * self.selectedLift * 10) / 10;
        var liftY = Math.round((cy / length) * self.selectedLift * 10) / 10;

        sector.setAttribute(
            'transform',
            baseTransform + ' translate(' + liftX + ' ' + liftY + ') scale(1.04)'
        );
    });

};