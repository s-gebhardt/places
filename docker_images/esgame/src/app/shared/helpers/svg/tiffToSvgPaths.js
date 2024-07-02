export function toIndex(x, y, width) {
    return y * width + x;
}
export default function tiffToSvgPaths(data, options = {}) {
    const UNDEFINED_VALUE = 0;
    let _a, _b, _c, _d, _e, _f;
    let bitmask, width, height, scale = 1, offsetX = 0, offsetY = 0;
    if (options.width) {
        bitmask = data;
        width = options.width;
        height = bitmask.length / width;
        if (height % 1 !== 0) {
            throw new Error(`Invalid bitmask width. ${height} = ${bitmask.length} / ${width}`);
        }
    }
    else if (data[0] instanceof Array) {
        bitmask = data.flat();
        width = data[0].length;
        height = data.length;
    }
    else {
        throw new Error(`options.width is required for 1 dimensional array.`);
    }
    if (options.scale) {
        scale = options.scale;
    }
    if (options.offsetX) {
        offsetX = options.offsetX;
    }
    if (options.offsetY) {
        offsetY = options.offsetY;
    }
    // Naively copy into a new bitmask with a border of 1 to make sampling easier (no out of bounds checks)
    const newWidth = width + 2;
    const newHeight = height + 2;
    const bm = Array(newWidth * newHeight).fill(0);
    // BM is just shifted over (1, 1) for the padding
    function BMXYToIndex(x, y) {
        return (y + 1) * newWidth + (x + 1);
    }
    for (let y = 0; y < height; ++y) {
        for (let x = 0; x < width; ++x) {
            bm[BMXYToIndex(x, y)] = bitmask[toIndex(x, y, width)];
        }
    }
    // Edges data structure has [x, y, nextEdge, group]
    const edgeXCount = width * (height + 1);

    const uniqueValues = new Set(bitmask);
    const valueGroups = new Map();

    for(let uniqueValue of uniqueValues) {
        // const a = new Array(edgeCount);
        // for (var i = 0; i < edgeCount; i++) {
        //     a[i] = { x: 0, y: 0, next: undefined };
        // }
        valueGroups.set(uniqueValue, { set: new Set(), edges: new Set() });
    }

    function EdgeXIndex(x, y) {
        return y * width + x;
    }
    function EdgeYIndex(x, y) {
        return edgeXCount + y * (width + 1) + x;
    }
    function SetEdge(edge, x, y, value) {
        edge.x = x;
        edge.y = y;
        valueGroups.get(value).set.add(edge);
    }
    function UnionGroup(edge, value) {
        for (var itr = edge.next; itr !== undefined && itr !== edge; itr = itr.next) {
            valueGroups.get(value).set.delete(itr);
        }
        if (itr !== undefined) {
            valueGroups.get(value).set.add(edge);
        }
    }

    function getEdge(edges, index) {
        let edge = edges[index];
        if(edge) {
            return edge;
        }
        edge = { x: 0, y: 0, next: undefined };
        edges[index] = edge;
        return edge;
    }

    for (let y = 0; y < height; ++y) {
        for (let x = 0; x < width; ++x) {
            if (bm[BMXYToIndex(x, y)] !== UNDEFINED_VALUE) {
                const edges = valueGroups.get(bm[BMXYToIndex(x, y)]).edges;
                const currentValue = bm[BMXYToIndex(x, y)];
                const left = bm[BMXYToIndex(x - 1, y)];
                if (left !== currentValue) {
                    const edge = getEdge(edges, EdgeYIndex(x, y));
                    SetEdge(edge, x, y + 1, currentValue);
                    if (bm[BMXYToIndex(x - 1, y - 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeXIndex(x - 1, y));
                    }
                    else if (bm[BMXYToIndex(x, y - 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeYIndex(x, y - 1));
                    }
                    else {
                        edge.next = getEdge(edges, EdgeXIndex(x, y));
                    }
                    UnionGroup(edge, currentValue);
                }
                const right = bm[BMXYToIndex(x + 1, y)];
                if (right !== currentValue) {
                    const edge = getEdge(edges, EdgeYIndex(x + 1, y));
                    SetEdge(edge, x + 1, y, currentValue);
                    if (bm[BMXYToIndex(x + 1, y + 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeXIndex(x + 1, y + 1));
                    }
                    else if (bm[BMXYToIndex(x, y + 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeYIndex(x + 1, y + 1));
                    }
                    else {
                        edge.next = getEdge(edges, EdgeXIndex(x, y + 1));
                    }
                    UnionGroup(edge, currentValue);
                }
                const top = bm[BMXYToIndex(x, y - 1)];
                if (top !== currentValue) {
                    const edge = getEdge(edges, EdgeXIndex(x, y));
                    SetEdge(edge, x, y, currentValue);
                    if (bm[BMXYToIndex(x + 1, y - 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeYIndex(x + 1, y - 1));
                    }
                    else if (bm[BMXYToIndex(x + 1, y)] === currentValue) {
                        edge.next = getEdge(edges, EdgeXIndex(x + 1, y));
                    }
                    else {
                        edge.next = getEdge(edges, EdgeYIndex(x + 1, y));
                    }
                    UnionGroup(edge, currentValue);
                }
                const bottom = bm[BMXYToIndex(x, y + 1)];
                if (bottom !== currentValue) {
                    const edge = getEdge(edges, EdgeXIndex(x, y + 1));
                    SetEdge(edge, x + 1, y + 1, currentValue);
                    if (bm[BMXYToIndex(x - 1, y + 1)] === currentValue) {
                        edge.next = getEdge(edges, EdgeYIndex(x, y + 1));
                    }
                    else if (bm[BMXYToIndex(x - 1, y)] === currentValue) {
                        edge.next = getEdge(edges, EdgeXIndex(x - 1, y + 1));
                    }
                    else {
                        edge.next = getEdge(edges, EdgeYIndex(x, y));
                    }
                    UnionGroup(edge, currentValue);
                }
            }
        }
    }

    for (const key of valueGroups.keys()) {
        const group = valueGroups.get(key).set;
        for (const edge of group) {
            let itr = edge;
            do {
                if (itr.next) {
                    itr.next.type = itr.x == ((_a = itr === null || itr === void 0 ? void 0 : itr.next) === null || _a === void 0 ? void 0 : _a.x) ? 'V' : 'H';
                    itr = itr.next;
                }
            } while (itr !== edge);
        }
    }
    // Compress sequences of H and V
    for (let key of valueGroups.keys()) {
        const group = valueGroups.get(key).set;
        for (let edge of group) {
            let itr = edge;
            do {
                if (itr.type != ((_b = itr.next) === null || _b === void 0 ? void 0 : _b.type)) {
                    while (((_c = itr.next) === null || _c === void 0 ? void 0 : _c.type) == ((_e = (_d = itr.next) === null || _d === void 0 ? void 0 : _d.next) === null || _e === void 0 ? void 0 : _e.type)) {
                        if (itr.next === edge) {
                            valueGroups.get(key).set.delete(edge);
                            edge = itr.next.next;
                            valueGroups.get(key).set.add(edge); // Note this will cause it to iterate over this group again, meh.
                        }
                        itr.next = (_f = itr.next) === null || _f === void 0 ? void 0 : _f.next;
                    }
                }
                itr = itr.next;
            } while (itr !== edge);
        }
    }
    let paths = new Map();
    for (let key of valueGroups.keys()) {
        const groups = valueGroups.get(key).set;
        let path = '';
        for (const edge of groups) {
            path += `M${edge.x * scale},${edge.y * scale}`;
            for (let itr = edge.next; itr != edge; itr = itr === null || itr === void 0 ? void 0 : itr.next) {
                if ((itr === null || itr === void 0 ? void 0 : itr.type) == 'H') {
                    path += `H${((itr === null || itr === void 0 ? void 0 : itr.x) * scale) + offsetX}`;
                }
                else if ((itr === null || itr === void 0 ? void 0 : itr.type) == 'V') {
                    path += `V${((itr === null || itr === void 0 ? void 0 : itr.y) * scale) + offsetY}`;
                }
            }
            path += 'Z';
        }
        paths.set(key, path);
    }
    return paths;
}
