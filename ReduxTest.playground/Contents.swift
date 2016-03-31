import UIKit

/*:
## Redux 
A Predictable state container for not just JavaScript apps
*/

/*:
### Action
Payload of information from app to your __Store__
*/

protocol ActionType {
  init()
}

struct DefaultAction : ActionType {
  init() { }
}

protocol StandardAction : ActionType {
  var type: String { get }
  var payload: Any? { get }
}

/*:
### State
Single source of truth for your __Store__
*/

struct TodoState {
  var todos: [String]
}

/*:
### Reducer
Function that explains how you react to your __State__ when __Action__ happened

`(previousState, action) -> newState`
*/

func reducer(state: TodoState? = nil, action: ActionType) -> TodoState {
  //do something with state
  return TodoState(todos: [])
}

/*:
### Store
Object that glues everything together, responsibilities of Store are;
* Hold app state
* Allow access state via `getState()`
* Allow action to be dispatched via `dispatch(action)`
* Register/Notify listeners via `subscribe(listener)`
*/

protocol DisposableType {
  var dispose: () -> () { get }
}

struct DefaultDisposable : DisposableType {
  let dispose: () -> ()
  init(dispose: () -> ()) {
    self.dispose = dispose
  }
}

protocol StoreType {
  associatedtype State
  
  var getState: () -> State { get }
  var dispatch: ActionType -> ActionType { get }
  var subscribe: (State -> ()) -> DisposableType { get }
}

struct Store<State> : StoreType {
  let getState: () -> State
  let dispatch: ActionType -> ActionType
  let subscribe: (State -> ()) -> DisposableType
  
  init(getState: () -> State, dispatch: ActionType -> ActionType, subscribe: (State -> ()) -> DisposableType) {
    self.getState = getState
    self.dispatch = dispatch
    self.subscribe = subscribe
  }
}

func createStore<State>(reducer: (State?, ActionType) -> State, state: State?) -> Store<State> {
  typealias Subscriber = State -> ()
  
  var currentState = state ?? reducer(state, DefaultAction())
  var subscribers = [String: Subscriber]()
  
  func _dispatch(action: ActionType) -> ActionType {
    //reduce state
    currentState = reducer(currentState, action)
    //notify subscriber
    for (_, s) in subscribers {
      s(currentState)
    }
    return action
  }
  
  func _subscribe(subscriber: State -> ()) -> DisposableType {
    let key = NSUUID().UUIDString
    subscribers[key] = subscriber
    return DefaultDisposable(dispose: { subscribers.removeValueForKey(key) })
  }
  
  return Store(getState: { currentState }, dispatch: _dispatch, subscribe: _subscribe)
}

/*:
### Let's have some fun with Redux
Assume that we are building todo app
*/

// define actions
struct AddTodoAction : StandardAction {
  let type: String = "ADD_TODO"
  let payload: Any?
  
  init() {
    payload = ""
  }
  
  init(payload: String) {
    self.payload = payload
  }
}

struct RemoveTodoAction : StandardAction {
  let type: String = "REMOVE_TODO"
  let payload: Any?
  
  init() {
    payload = ""
  }
  
  init(payload: Int) {
    self.payload = payload
  }
}

struct RemoveAllTodosAction : StandardAction {
  let type: String = "CLEAR_TODO"
  let payload: Any?
  
  init() {
    payload = nil
  }
  
}

// define reducer
func todoReducer(state: TodoState? = nil, action: ActionType) -> TodoState {
  let currentState = state ?? TodoState(todos: [])
  
  var todos = currentState.todos
  switch action {
    case let action as AddTodoAction:
      todos.append(action.payload as! String)
    case let action as RemoveTodoAction:
      todos.removeAtIndex(action.payload as! Int)
    case _ as RemoveAllTodosAction:
      todos.removeAll()
    default:
      break
  }
  
  return TodoState(todos: todos)
}

let store = createStore(todoReducer, state: nil)
var count = 0

let d = store.subscribe { s in
  print(s.todos)
  count += 1
}

store.dispatch(AddTodoAction(payload: "Learn Redux for iOS"))
store.dispatch(AddTodoAction(payload: "Buy shampoo at Tops"))
store.dispatch(AddTodoAction(payload: "Watch series on Netflix"))
store.dispatch(AddTodoAction(payload: "Call daddy"))
store.dispatch(RemoveTodoAction(payload: 2))
store.dispatch(RemoveTodoAction(payload: 0))
store.dispatch(RemoveAllTodosAction())
count

import XCPlayground
import SnapKit

struct App {
  static let store = createStore(todoReducer, state: nil)
}

class TodosViewController: UIViewController {

  let state: () -> TodoState = App.store.getState

  let tableView = UITableView()
  let navigationBar = UINavigationBar()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setUpTableView()
    setUpNavigationBar()
    
    App.store.subscribe { _ in
      self.tableView.reloadData()
    }
  }

  private func setUpTableView() {
    tableView.dataSource = self
    tableView.delegate = self
    tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    tableView.separatorStyle = .None
  
    view.addSubview(tableView)
    tableView.snp_makeConstraints { make in
      make.edges.equalTo(view).inset(UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0))
    }
  }

  private func setUpNavigationBar() {
    
    let navigationItem = UINavigationItem(title: "Todos")
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: #selector(TodosViewController.addTodo(_:)))
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(TodosViewController.removeAllTodos(_:)))
    
    navigationBar.setItems([navigationItem], animated: false)
    
    view.addSubview(navigationBar)
      navigationBar.snp_makeConstraints { make in
      make.height.equalTo(50)
      make.width.equalTo(view)
    }
  }
}

extension TodosViewController {
  func addTodo(item: UIBarButtonItem) {
    struct holder {
      static var time = 0
    }
    holder.time += 1
    App.store.dispatch(AddTodoAction(payload: "Redux is awesome: \(holder.time)"))
  }
}

extension TodosViewController {
  func removeAllTodos(item: UIBarButtonItem) {
    App.store.dispatch(RemoveAllTodosAction())
  }
}

extension TodosViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
    return state().todos.count;
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell{
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
    cell.textLabel?.text = state().todos[indexPath.row]
    return cell
  }
}

extension TodosViewController : UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    // remove item
    App.store.dispatch(RemoveTodoAction(payload: indexPath.row))
  }
}

var vc = TodosViewController()
XCPlaygroundPage.currentPage.liveView = vc.view