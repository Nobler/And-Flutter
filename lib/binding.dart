import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void runAndroidApp(View view) {
  ViewAndroidBinding.ensureInitialized()
      ..scheduleAttachRootWidget(view)
      ..scheduleWarmUpFrame();
}

abstract class Context{
  View get view;

  BuildOwner? get owner;
}

abstract class SingleChildRenderObjectView extends RenderObjectView {
  SingleChildRenderObjectView(this.child);

  final View? child;

  @override
  SingleChildRenderObjectElement createElement() => SingleChildRenderObjectElement(this);
}

abstract class RenderObjectView extends View {
  @override
  RenderObjectElement createElement();

  @protected
  RenderObject createRenderObject(Context context);

  @protected
  void updateRenderObject(Context context, covariant RenderObject renderObject){}
}

abstract class View{

  Element? _element;

  @protected
  Element createElement();

  void _onAttach(Element element) {
    _element = element;
  }

  @protected
  void invalidate(){
    _element!.markNeedsBuild();
  }
}

class SingleChildRenderObjectElement extends RenderObjectElement {
  SingleChildRenderObjectElement(RenderObjectView view) : super(view);

  @override
  SingleChildRenderObjectView get view => super.view as SingleChildRenderObjectView;

  @override
  void mount(Element? parent) {
    super.mount(parent);

    updateChild(null, view.child);
  }
}

class RenderObjectToViewAdapter extends RenderObjectView {

  RenderObjectToViewAdapter(this.child, this.container);

  final View child;

  final RenderObject container;

  @override
  RootRenderObjectElement createElement() => RootRenderObjectElement(this);

  @override
  RenderObject createRenderObject(Context context) => container;

  RootRenderObjectElement attachToRenderTree(BuildOwner owner) {
    RootRenderObjectElement element = createElement();

    element.assignOwner(owner);

    owner.buildScope(element, () {
      element.mount(null);
    });

    return element;
  }
}

class RootRenderObjectElement extends RenderObjectElement {

  RootRenderObjectElement(RenderObjectToViewAdapter view):super(view);

  @override
  RenderObjectToViewAdapter get view => super.view as RenderObjectToViewAdapter;

  void assignOwner(BuildOwner owner) {
    _owner = owner;
  }

  @override
  void mount(Element? parent) {
    super.mount(parent);

    updateChild(null, view.child);
  }
}

abstract class RenderObjectElement extends Element {

  RenderObjectElement(RenderObjectView view) : super(view);

  @override
  RenderObject get renderObject {
    assert(_renderObject != null, '$runtimeType unmounted');
    return _renderObject!;
  }
  RenderObject? _renderObject;

  @override
  RenderObjectView get view => super.view as RenderObjectView;

  @override
  @protected
  void performRebuild() {
    view.updateRenderObject(this, renderObject);

    _dirty = false;
  }

  @override
  void mount(Element? parent) {
    super.mount(parent);

    _renderObject = view.createRenderObject(this);

    _dirty = false;
  }
}

// abstract class ComponentElement extends Element {
//   ComponentElement(View view) : super(view);
//
//   @override
//   void mount(Element? parent) {
//     super.mount(parent);
//
//     rebuild();
//   }
//
//   @override
//   void performRebuild() {
//     View view = build();
//
//     updateChild(null, view);
//   }
//
//   @protected
//   View build();
// }

abstract class Element extends Context{
  Element(View view) : _view = view;

  @override
  View get view => _view!;
  View? _view;

  Element? _parent;

  RenderObject? get renderObject;

  bool get dirty => _dirty;
  bool _dirty = true;

  @override
  BuildOwner? get owner => _owner;
  BuildOwner? _owner;

  void rebuild(){
    performRebuild();
  }

  void performRebuild();

  void mount(Element? parent) {
    _parent = parent;

    if (parent != null) {
      _owner = parent.owner;
    }
  }

  // widget is immutable
  @protected
  Element? updateChild(Element? child, View? newView) {
    if (newView == null) return null;

    if (child != null) {
      child._parent = null;
      child.detachRenderObject();
    }

    final Element newChild = newView.createElement();
    newView._onAttach(newChild);

    newChild.mount(this);

    return newChild;
  }

  void markNeedsBuild() {
    if (dirty) {
      return;
    }
    _dirty = true;
    owner!.scheduleBuildFor(this);
  }

  void detachRenderObject() {

  }
}

class BuildOwner {

  VoidCallback? onBuildScheduled;

  final List<Element> _dirtyElements = [];

  bool _scheduledFlushDirtyElements = false;

  void scheduleBuildFor(Element view) {
    if (!_scheduledFlushDirtyElements && onBuildScheduled != null) {
      _scheduledFlushDirtyElements = true;
      onBuildScheduled!();
    }

    _dirtyElements.add(view);
  }

  void buildScope(Element parent,[ VoidCallback? callback ]) {
    if (callback != null) {
      callback();
    }

    int dirtyCount = _dirtyElements.length;
    int index = 0;
    while (index < dirtyCount) {
      try {
        _dirtyElements[index].rebuild();
      } catch (e) {
      }
    }

    _dirtyElements.clear();
    _scheduledFlushDirtyElements = false;
  }
}

mixin ViewBinding on BindingBase, ServicesBinding, SchedulerBinding, GestureBinding, RendererBinding, SemanticsBinding {
  BuildOwner? get buildOwner => _buildOwner;
  BuildOwner? _buildOwner;

  static ViewBinding? get instance => _instance;
  static ViewBinding? _instance;

  Element? get renderViewElement => _renderViewElement;
  Element? _renderViewElement;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;

    _buildOwner = BuildOwner();
    buildOwner!.onBuildScheduled = _handleBuildScheduled;
  }

  void _handleBuildScheduled() {
    ensureVisualUpdate();
  }

  void scheduleAttachRootWidget(View rootView) {
    Timer.run(() {
      attachRootView(rootView);
    });
  }

  void attachRootView(View view) {
    _renderViewElement = RenderObjectToViewAdapter(view, renderView)
        .attachToRenderTree(buildOwner!);
  }

  @override
  void drawFrame() {
    _buildOwner!.buildScope(renderViewElement!);
    super.drawFrame();
  }
}

class ViewAndroidBinding extends BindingBase with GestureBinding, SchedulerBinding, ServicesBinding, PaintingBinding, SemanticsBinding, RendererBinding, ViewBinding {
  static ViewBinding ensureInitialized() {
    if (ViewBinding.instance == null) {
      ViewAndroidBinding();
    }
    return ViewBinding.instance!;
  }
}