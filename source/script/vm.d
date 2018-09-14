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

module script.vm;

import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.math;

import core.indexedarray;
import script.primitive;
import script.compiler;
import script.coroutine;
import script.any;
import script.array;
import script.type;
import script.bytecode;

class GrimoireVM {
	uint[] opcodes;

	int[] iconsts;
	float[] fconsts;
	dstring[] sconsts;

	int[] iglobals;
	float[] fglobals;
	dstring[] sglobals;

	int[] iglobalStack;
	float[] fglobalStack;
	dstring[] sglobalStack;
	AnyValue[][] nglobalStack;
	AnyValue[] aglobalStack;
	void*[] oglobalStack;

	IndexedArray!(Coroutine, 256u) coroutines = new IndexedArray!(Coroutine, 256u)();

    __gshared bool isRunning = true;

    @property {
        bool hasCoroutines() const { return coroutines.length > 0uL; }
    }

	this() {}

	this(Bytecode bytecode) {
		load(bytecode);
	}

	void load(Bytecode bytecode) {
		iconsts = bytecode.iconsts;
		fconsts = bytecode.fconsts;
		sconsts = bytecode.sconsts;
		opcodes = bytecode.opcodes;
	}

    void spawn() {
		coroutines.push(new Coroutine(this));
	}

	void process() {
		coroutinesLabel: for(uint index = 0u; index < coroutines.length; index ++) {
			Coroutine coro = coroutines.data[index];
			while(isRunning) {
				uint opcode = opcodes[coro.pc];
				switch (getInstruction(opcode)) with(Opcode) {
				case Task:
					Coroutine newCoro = new Coroutine(this);
					newCoro.pc = getValue(opcode);
					coroutines.push(newCoro);
					coro.pc ++;
					break;
				case AnonymousTask:
					Coroutine newCoro = new Coroutine(this);
					newCoro.pc = coro.istack[$ - 1];
					coro.istack.length --;
					coroutines.push(newCoro);
					coro.pc ++;
					break;
				case Kill:
					coroutines.markInternalForRemoval(index);
					continue coroutinesLabel;
				case Yield:
					coro.pc ++;
					continue coroutinesLabel;
				case PopStack_Int:
					coro.istack.length -= getValue(opcode);
					coro.pc ++;
					break;
				case PopStack_Float:
					coro.fstack.length -= getValue(opcode);
					coro.pc ++;
					break;
				case PopStack_String:
					coro.sstack.length -= getValue(opcode);
					coro.pc ++;
					break;
                case PopStack_Array:
					coro.nstack.length -= getValue(opcode);
					coro.pc ++;
					break;
				case PopStack_Any:
					coro.astack.length -= getValue(opcode);
					coro.pc ++;
					break;
				case PopStack_Object:
					coro.ostack.length -= getValue(opcode);
					coro.pc ++;
					break;
				case LocalStore_Int:
					coro.ivalues[coro.valuesPos + getValue(opcode)] = coro.istack[$ - 1];
                    coro.istack.length --;	
					coro.pc ++;
					break;
				case LocalStore_Float:
					coro.fvalues[coro.valuesPos + getValue(opcode)] = coro.fstack[$ - 1];
                    coro.fstack.length --;	
					coro.pc ++;
					break;
				case LocalStore_String:
					coro.svalues[coro.valuesPos + getValue(opcode)] = coro.sstack[$ - 1];		
                    coro.sstack.length --;	
					coro.pc ++;
					break;
                case LocalStore_Array:
					coro.nvalues[coro.valuesPos + getValue(opcode)] = coro.nstack[$ - 1];		
                    coro.nstack.length --;	
					coro.pc ++;
					break;
				case LocalStore_Any:
					coro.avalues[coro.valuesPos + getValue(opcode)] = coro.astack[$ - 1];
                    coro.astack.length --;	
					coro.pc ++;
					break;
                case LocalStore_Ref:
                    coro.astack[$ - 2].setRef(coro.astack[$ - 1]);
                    coro.astack.length -= 2;
                    coro.pc ++;
                    break;
				case LocalStore_Object:
					coro.ovalues[coro.valuesPos + getValue(opcode)] = coro.ostack[$ - 1];
                    coro.ostack.length --;	
					coro.pc ++;
					break;
                case LocalStore2_Int:
					coro.ivalues[coro.valuesPos + getValue(opcode)] = coro.istack[$ - 1];
					coro.pc ++;
					break;
				case LocalStore2_Float:
					coro.fvalues[coro.valuesPos + getValue(opcode)] = coro.fstack[$ - 1];
					coro.pc ++;
					break;
				case LocalStore2_String:
					coro.svalues[coro.valuesPos + getValue(opcode)] = coro.sstack[$ - 1];		
					coro.pc ++;
					break;
                case LocalStore2_Array:
					coro.nvalues[coro.valuesPos + getValue(opcode)] = coro.nstack[$ - 1];		
					coro.pc ++;
					break;
				case LocalStore2_Any:
					coro.avalues[coro.valuesPos + getValue(opcode)] = coro.astack[$ - 1];
					coro.pc ++;
					break;
                case LocalStore2_Ref:
                    coro.astack[$ - 2].setRef(coro.astack[$ - 1]);
                    coro.astack.length --;
                    coro.pc ++;
                    break;
				case LocalStore2_Object:
					coro.ovalues[coro.valuesPos + getValue(opcode)] = coro.ostack[$ - 1];
					coro.pc ++;
					break;
				case LocalLoad_Int:
					coro.istack ~= coro.ivalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
				case LocalLoad_Float:
					coro.fstack ~= coro.fvalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
				case LocalLoad_String:
					coro.sstack ~= coro.svalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
                case LocalLoad_Array:
					coro.nstack ~= coro.nvalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
				case LocalLoad_Any:
					coro.astack ~= coro.avalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
                case LocalLoad_Ref:
                    AnyValue value;
                    value.setRefArray(&coro.nvalues[coro.valuesPos + getValue(opcode)]);
                    coro.astack ~= value;					
					coro.pc ++;
					break;
				case LocalLoad_Object:
					coro.ostack ~= coro.ovalues[coro.valuesPos + getValue(opcode)];
					coro.pc ++;
					break;
				case Const_Int:
					coro.istack ~= iconsts[getValue(opcode)];
					coro.pc ++;
					break;
				case Const_Float:
					coro.fstack ~= fconsts[getValue(opcode)];
					coro.pc ++;
					break;
				case Const_Bool:
					coro.istack ~= getValue(opcode);
					coro.pc ++;
					break;
				case Const_String:
					coro.sstack ~= sconsts[getValue(opcode)];
					coro.pc ++;
					break;
				case GlobalPush_Int:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						iglobalStack ~= coro.istack[($ - nbParams) + i];
					coro.istack.length -= nbParams;
					coro.pc ++;
					break;
				case GlobalPush_Float:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						fglobalStack ~= coro.fstack[($ - nbParams) + i];
					coro.fstack.length -= nbParams;
					coro.pc ++;
					break;
				case GlobalPush_String:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						sglobalStack ~= coro.sstack[($ - nbParams) + i];
					coro.sstack.length -= nbParams;
					coro.pc ++;
					break;
                case GlobalPush_Array:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						nglobalStack ~= coro.nstack[($ - nbParams) + i];
					coro.nstack.length -= nbParams;
					coro.pc ++;
					break;
				case GlobalPush_Any:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						aglobalStack ~= coro.astack[($ - nbParams) + i];
					coro.astack.length -= nbParams;
					coro.pc ++;
					break;
				case GlobalPush_Object:
					uint nbParams = getValue(opcode);
					for(uint i = 0u; i < nbParams; i++)
						oglobalStack ~= coro.ostack[($ - nbParams) + i];
					coro.ostack.length -= nbParams;
					coro.pc ++;
					break;
				case GlobalPop_Int:
					coro.istack ~= iglobalStack[$ - 1];
					iglobalStack.length --;
					coro.pc ++;
					break;
				case GlobalPop_Float:
					coro.fstack ~= fglobalStack[$ - 1];
					fglobalStack.length --;
					coro.pc ++;
					break;
				case GlobalPop_String:
					coro.sstack ~= sglobalStack[$ - 1];
					sglobalStack.length --;
					coro.pc ++;
					break;
                case GlobalPop_Array:
					coro.nstack ~= nglobalStack[$ - 1];
					nglobalStack.length --;
					coro.pc ++;
					break;
				case GlobalPop_Any:
					coro.astack ~= aglobalStack[$ - 1];
					aglobalStack.length --;
					coro.pc ++;
					break;
				case GlobalPop_Object:
					coro.ostack ~= oglobalStack[$ - 1];
					oglobalStack.length --;
					coro.pc ++;
					break;
                case ConvertBoolToAny:
					AnyValue value;
					value.setBool(coro.istack[$ - 1]);
					coro.istack.length --;
					coro.astack ~= value;
					coro.pc ++;
					break;
				case ConvertIntToAny:
					AnyValue value;
					value.setInteger(coro.istack[$ - 1]);
					coro.istack.length --;
					coro.astack ~= value;
					coro.pc ++;
					break;
				case ConvertFloatToAny:
					AnyValue value;
					value.setFloat(coro.fstack[$ - 1]);
					coro.fstack.length --;
					coro.astack ~= value;
					coro.pc ++;
					break;
				case ConvertStringToAny:
					AnyValue value;
					value.setString(coro.sstack[$ - 1]);
					coro.sstack.length --;
					coro.astack ~= value;
					coro.pc ++;
					break;
                case ConvertArrayToAny:
					AnyValue value;
					value.setArray(coro.nstack[$ - 1]);
					coro.nstack.length --;
					coro.astack ~= value;
					coro.pc ++;
					break;
				case ConvertAnyToBool:
					coro.istack ~= coro.astack[$ - 1].getBool();
					coro.astack.length --;
					coro.pc ++;
					break;
                case ConvertAnyToInt:
					coro.istack ~= coro.astack[$ - 1].getInteger();
					coro.astack.length --;
					coro.pc ++;
					break;
				case ConvertAnyToFloat:
					coro.fstack ~= coro.astack[$ - 1].getFloat();
					coro.astack.length --;
					coro.pc ++;
					break;
				case ConvertAnyToString:
					coro.sstack ~= coro.astack[$ - 1].getString();
					coro.astack.length --;
					coro.pc ++;
					break;
                case ConvertAnyToArray:
					coro.nstack ~= coro.astack[$ - 1].getArray();
					coro.astack.length --;
					coro.pc ++;
					break;
				case Equal_Int:
					coro.istack[$ - 2] = coro.istack[$ - 2] == coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case Equal_Float:
					coro.istack ~= coro.fstack[$ - 2] == coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
				case Equal_String:
					coro.istack ~= coro.sstack[$ - 2] == coro.sstack[$ - 1];
					coro.sstack.length -= 2;
					coro.pc ++;
					break;
				//Equal_Any
				case NotEqual_Int:
					coro.istack[$ - 2] = coro.istack[$ - 2] != coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case NotEqual_Float:
					coro.istack ~= coro.fstack[$ - 2] != coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
				case NotEqual_String:
					coro.istack ~= coro.sstack[$ - 2] != coro.sstack[$ - 1];
					coro.sstack.length -= 2;
					coro.pc ++;
					break;
				//NotEqual_Any
				case GreaterOrEqual_Int:
					coro.istack[$ - 2] = coro.istack[$ - 2] >= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case GreaterOrEqual_Float:
					coro.istack ~= coro.fstack[$ - 2] >= coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
					//Any
				case LesserOrEqual_Int:
					coro.istack[$ - 2] = coro.istack[$ - 2] <= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case LesserOrEqual_Float:
					coro.istack ~= coro.fstack[$ - 2] <= coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
					//any
				case GreaterInt:
					coro.istack[$ - 2] = coro.istack[$ - 2] > coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case GreaterFloat:
					coro.istack ~= coro.fstack[$ - 2] > coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
					//any
				case LesserInt:
					coro.istack[$ - 2] = coro.istack[$ - 2] < coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case LesserFloat:
					coro.istack ~= coro.fstack[$ - 2] < coro.fstack[$ - 1];
					coro.fstack.length -= 2;
					coro.pc ++;
					break;
					//any
				case AndInt:
					coro.istack[$ - 2] = coro.istack[$ - 2] && coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case OrInt:
					coro.istack[$ - 2] = coro.istack[$ - 2] || coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case NotInt:
					coro.istack[$ - 1] = !coro.istack[$ - 1];
					coro.pc ++;
					break;
					//any
				case AddInt:
					coro.istack[$ - 2] += coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case AddFloat:
					coro.fstack[$ - 2] += coro.fstack[$ - 1];
					coro.fstack.length --;
					coro.pc ++;
					break;
				case AddAny:
					coro.astack[$ - 2] += coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case ConcatenateString:
					coro.sstack[$ - 2] ~= coro.sstack[$ - 1];
					coro.sstack.length --;
					coro.pc ++;
					break;
				case ConcatenateAny:
					coro.astack[$ - 2] ~= coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case SubstractInt:
					coro.istack[$ - 2] -= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case SubstractFloat:
					coro.fstack[$ - 2] -= coro.fstack[$ - 1];
					coro.fstack.length --;
					coro.pc ++;
					break;
				case SubstractAny:
					coro.astack[$ - 2] -= coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case MultiplyInt:
					coro.istack[$ - 2] *= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case MultiplyFloat:
					coro.fstack[$ - 2] *= coro.fstack[$ - 1];
					coro.fstack.length --;
					coro.pc ++;
					break;
				case MultiplyAny:
					coro.astack[$ - 2] *= coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case DivideInt:
					coro.istack[$ - 2] /= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case DivideFloat:
					coro.fstack[$ - 2] /= coro.fstack[$ - 1];
					coro.fstack.length --;
					coro.pc ++;
					break;
				case DivideAny:
					coro.astack[$ - 2] /= coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case RemainderInt:
					coro.istack[$ - 2] %= coro.istack[$ - 1];
					coro.istack.length --;
					coro.pc ++;
					break;
				case RemainderFloat:
					coro.fstack[$ - 2] %= coro.fstack[$ - 1];
					coro.fstack.length --;
					coro.pc ++;
					break;
				case RemainderAny:
					coro.astack[$ - 2] %= coro.astack[$ - 1];
					coro.astack.length --;
					coro.pc ++;
					break;
				case NegativeInt:
					coro.istack[$ - 1] = -coro.istack[$ - 1];
					coro.pc ++;
					break;
				case NegativeFloat:
					coro.fstack[$ - 1] = -coro.fstack[$ - 1];
					coro.pc ++;
					break;
				case NegativeAny:
					coro.astack[$ - 1] = -coro.astack[$ - 1];
					coro.pc ++;
					break;
				case IncrementInt:
					coro.istack[$ - 1] ++;
					coro.pc ++;
					break;
				case IncrementFloat:
					coro.fstack[$ - 1] += 1f;
					coro.pc ++;
					break;
				case IncrementAny:
					coro.astack[$ - 1] ++;
					coro.pc ++;
					break;
				case DecrementInt:
					coro.istack[$ - 1] --;
					coro.pc ++;
					break;
				case DecrementFloat:
					coro.fstack[$ - 1] -= 1f;
					coro.pc ++;
					break;
				case DecrementAny:
					coro.astack[$ - 1] --;
					coro.pc ++;
					break;
				case LocalStore_upIterator:
					if(coro.istack[$ - 1] < 0)
						coro.istack[$ - 1] = 0;
					coro.istack[$ - 1] ++;
					coro.pc ++;
					break;
				case Return:
					coro.stackPos -= 2;
					coro.pc = coro.callStack[coro.stackPos + 1u];
					coro.valuesPos -= coro.callStack[coro.stackPos];
					break;
				case LocalStack:
                    auto stackSize = getValue(opcode);
					coro.callStack[coro.stackPos] = stackSize;
                    stackSize = coro.valuesPos + stackSize;
                    coro.ivalues.length = stackSize;
                    coro.fvalues.length = stackSize;
                    coro.svalues.length = stackSize;
                    coro.nvalues.length = stackSize;
                    coro.avalues.length = stackSize;
                    coro.ovalues.length = stackSize;
					coro.pc ++;
					break;
				case Call:
					coro.valuesPos += coro.callStack[coro.stackPos];
					coro.callStack[coro.stackPos + 1u] = coro.pc + 1u;
					coro.stackPos += 2;
					coro.pc = getValue(opcode);
					break;
				case AnonymousCall:
					coro.valuesPos += coro.callStack[coro.stackPos];
					coro.callStack[coro.stackPos + 1u] = coro.pc + 1u;
					coro.stackPos += 2;
					coro.pc = coro.istack[$ - 1];
					coro.istack.length --;
					break;
				case PrimitiveCall:
					primitives[getValue(opcode)].callback(coro);
					coro.pc ++;
					break;
				case Jump:
					coro.pc += getSignedValue(opcode);
					break;
				case JumpEqual:
					if(coro.istack[$ - 1])
						coro.pc ++;
					else
						coro.pc += getSignedValue(opcode);
					coro.istack.length --;
					break;
				case JumpNotEqual:
					if(coro.istack[$ - 1])
						coro.pc += getSignedValue(opcode);
					else
						coro.pc ++;
					coro.istack.length --;
					break;
                case ArrayBuild:
                    AnyValue[] ary;
                    const auto arySize = getValue(opcode);
                    for(int i = arySize; i > 0; i --) {
                        ary ~= coro.astack[$ - i];
                    }
                    coro.astack.length -= arySize;
                    coro.nstack ~= ary;
                    coro.pc ++;
                    break;
				case ArrayLength:
					coro.istack ~= cast(int)coro.nstack[$ - 1].length;
                    coro.nstack.length --;
					coro.pc ++;
					break;
				case ArrayIndex:
					coro.astack ~= coro.nstack[$ - 1][coro.istack[$ - 1]];
					coro.nstack.length --;					
					coro.istack.length --;					
					coro.pc ++;
					break;
                case ArrayIndexRef:
                    coro.astack[$ - 1].setArrayIndex(coro.istack[$ - 1]);
                    coro.istack.length --;
					coro.pc ++;
					break;
				default:
					throw new Exception("Invalid instruction");
				}
			}
		}
		coroutines.sweepMarkedData();
    }
}