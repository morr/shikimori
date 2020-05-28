import { icons, MenuItem, wrapItem, liftItem } from 'prosemirror-menu';
// import { TextSelection } from 'prosemirror-state';
import { toggleMark } from 'prosemirror-commands';
import { wrapInList } from 'prosemirror-schema-list';
import { schema } from './schema';


function cmdItem(cmd, options) {
  const passedOptions = {
    label: options.title,
    run: cmd
  };
  for (const prop in options) passedOptions[prop] = options[prop]; // eslint-disable-line
  if ((!options.enable || options.enable === true) && !options.select) {
    passedOptions[options.enable ? 'enable' : 'select'] = state => cmd(state);
  }

  return new MenuItem(passedOptions);
}

function wrapListItem(nodeType, options) {
  return cmdItem(wrapInList(nodeType, options.attrs), options);
}

const markActive = markType => state => {
  const { from, $from, to, empty } = state.selection;
  if (empty) {
    return markType.isInSet(state.storedMarks || $from.marks());
  }
  return state.doc.rangeHasMark(from, to, markType);
};

// const canInsert = nodeType => state => {
//   const { $from } = state.selection;
//   for (let d = $from.depth; d >= 0; d--) {
//     const index = $from.index(d);
//     if ($from.node(d).canReplaceWith(index, index, nodeType)) {
//       return true;
//     }
//   }
//   return false;
// };

// const insertBlockAfter = (node, state, dispatch) => {
//   const { tr } = state;
//   const pos = tr.selection.$anchor.after();

//   tr.insert(pos, node);
//   const selection = TextSelection.near(tr.doc.resolve(pos));

//   tr.setSelection(selection);
//   if (dispatch) {
//     dispatch(tr);
//   }
// };

// const insertBlock = nodeType => (state, dispatch) => {
//   insertBlockAfter(nodeType.createAndFill(), state, dispatch);
// };

export const menu = {
  floating: true,
  content: [
    [
      new MenuItem({
        title: 'Toggle Strong',
        icon: icons.strong,
        enable: () => true,
        active: markActive(schema.marks.strong),
        run: toggleMark(schema.marks.strong)
      }),
      new MenuItem({
        title: 'Toggle Emphasis',
        icon: icons.em,
        enable: () => true,
        active: markActive(schema.marks.em),
        run: toggleMark(schema.marks.em)
      })
    ], [
      wrapListItem(schema.nodes.bullet_list, {
        title: 'Wrap in bullet list',
        icon: icons.bulletList
      }),
      wrapItem(schema.nodes.blockquote, {
        title: 'Wrap in block quote',
        icon: icons.blockquote
      }),
      liftItem
    ]
    // [
      // new MenuItem({
      //   title: 'Wrap in block quote',
      //   icon: icons.blockquote,
      //   enable: () => true,
      //   active: markActive(schema.marks.em),
      //   run: toggleMark(schema.marks.em)
      // })
    // ]
  ]
};
