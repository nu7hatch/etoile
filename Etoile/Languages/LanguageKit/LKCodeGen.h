#import <EtoileFoundation/EtoileFoundation.h>

/**
 * Code generator protocol.  Each AST node calls methods in a class conforming
 * to this protocol.  Methods which return a value return a pointer to a
 * generator-specific type, which can then be passed in to the generator later
 * when it expects a value.
 */
@protocol LKCodeGenerator
/**
 * Begin generating a module.  A module is a set of classes and categories
 * which are compiled and optimised at once.
 */
- (void) startModule;
/**
 * Finish generating a module.
 */
- (void) endModule;
/**
 * Create a new class, with the specified superclass and instance variables.
 * The types should be Objective-C type encoding strings.
 */
- (void) createSubclass:(NSString*)aClass
            subclassing:(NSString*)aSuperclass
          withCvarNames:(const char**)cVarNames 
                  types:(const char**)cVarTypes
          withIvarNames:(const char**)iVarNames 
                  types:(const char**)iVarTypes
                offsets:(int*)offsets;
/**
 * Finish the current class. 
 */
- (void) endClass;
/**
 * Create a new category with the specified name on the named class.
 */
- (void) createCategoryOn:(NSString*)aClass
                    named:(NSString*)aCategory;
/**
 * Finish the current category. 
 */
- (void) endCategory;
/**
 * Begin a class method with the specified type encoding and number of local
 * variables.  Local variables and arguments are indexed by number, the code
 * generator is not aware of any symbol table information.
 */
- (void) beginClassMethod:(const char*) aName
                withTypes:(const char*)types
                   locals:(unsigned)locals;
/**
 * Begin an instance method with the specified type encoding and number of local
 * variables.  Local variables and arguments are indexed by number, the code
 * generator is not aware of any symbol table information.
 */
- (void) beginInstanceMethod:(const char*) aName
                   withTypes:(const char*)types
                      locals:(unsigned)locals;
/**
 * Sends a message to a receiver which may be a SmallInt (a boxed Smalltalk
 * integer contained within an object pointer).
 */
- (void*) sendMessage:(const char*)aMessage
                types:(const char*)types
                   to:(void*)receiver
             withArgs:(void**)argv
                count:(unsigned)argc;
/**
 * Sends a message to the superclass.
 */
- (void*) sendSuperMessage:(const char*)sel
                     types:(const char*)seltypes
                  withArgs:(void**)argv
                     count:(unsigned)argc;
/**
 * Sends a message to an object.  Similar to
 * sendMessage:type:to:withargs:count: but requires that receiver be an
 * Objective-C object, not a small integer.
 */
- (void*) sendMessage:(const char*)aMessage
                types:(const char*)types
             toObject:(void*)receiver
             withArgs:(void**)argv
                count:(unsigned)argc;
/**
 * Store the specified value in the named class variable.
 */
- (void) storeValue:(void*)rval 
    inClassVariable:(NSString*) aClassVar;
- (void*) loadClassVariable:(NSString*) aSymbol;
/**
 * Stores a value at a specific offset from an object.  Used for instance
 * variables.
 */
- (void) storeValue:(void*)aValue
              ofType:(NSString*)aType
            atOffset:(unsigned)anOffset
          fromObject:(void*)anObject;
/**
 * Loads a value at a specific offset from an object.  Used for instance
 * variables.
 */
- (void*) loadValueOfType:(NSString*)aType
                 atOffset:(unsigned)anOffset
               fromObject:(void*)anObject;
/**
 * Begin generating a block expression with the specified number of arguments
 * and locals.  The bound variables are pointers to variables declared outside
 * the block's scope.
 */
- (void) beginBlockWithArgs:(unsigned)args
					 locals:(unsigned)locals
 			  boundVars:(void**)promoted
					  count:(int)index;
/**
 * Load a bound variable in a block that was passed in as a pointer to
 * beginBlockWithArgs:locals:boundVars:count:.
 */
- (void*) loadBlockVarAtIndex:(unsigned)index
					   offset:(unsigned)offset;
/**
 * Store a bound variable in a block that was passed in as a pointer to
 * beginBlockWithArgs:locals:boundVars:count:.
 */
- (void) storeValue:(void*) value
  inBlockVarAtIndex:(unsigned)index
             offset:(unsigned)offset;
/**
 * Returns 'self' in the current method.
 */
- (void*) loadSelf;
/**
 * Load a pointer to the named class.
 */
- (void*) loadClass:(NSString*)aClass;
/**
 * Stores a value in the specified local.
 */
- (void) storeValue:(void*)aVal inLocalAtIndex:(unsigned)index;
/**
 * Loads a pointer to a local variable.  Used when binding variables into
 * blocks.
 */
- (void*) loadPointerToLocalAtIndex:(unsigned)index;
/**
 * Loads a pointer to an argument.  Used when binding variables into blocks.
 */
- (void*) loadPointerToArgumentAtIndex:(unsigned)index;
/**
 * Load the value of the specified local variable.
 */
- (void*) loadLocalAtIndex:(unsigned)index;
/**
 * Load the value of the specified argument.
 */
- (void*) loadArgumentAtIndex:(unsigned)index;
/**
 * End the current method.
 */
- (void) endMethod;
/**
 * End the current block.  Subsequent calls will insert instructions into the
 * containing scope (the method, or another block).
 */
- (void*) endBlock;
/**
 * Specify the return value for a block.  For Smalltalk, this is the result of
 * the last statement in a block.  Non-local block returns are not yet
 * implemented.
 */
- (void) blockReturn:(void*)aValue;
/**
 * Set the return value for a method.
 */
- (void) setReturn:(void*)aValue;
/**
 * Returns a constant representing the string as an integer (either a SmallInt or a BigInt).
 */
- (void*) intConstant:(NSString*)aString;
/**
 * ReturnAs a constant representing the passed string.
 */
- (void*) stringConstant:(NSString*)aString;
/**
 * Returns nil as a constant.
 */
- (void*) nilConstant;
/**
 * Compares two pointers.
 */
- (void*) comparePointer:(void*)lhs to:(void*)rhs;
/**
 * Generates a constant symbol (a boxed selector).
 */
- (void*) generateConstantSymbol:(NSString*)aSymbol;
@end
/**
 * Returns the default code generator for JIT compilation.
 */
id <LKCodeGenerator> defaultJIT(void);
/**
 * Returns the default code generator for static compilation, outputting to the
 * file specified in the argument.
 */
id <LKCodeGenerator> defaultStaticCompilterWithFile(NSString*);