set pagination off
set confirm off
set print thread-events off
set print elements 32
set disable-randomization off
set debuginfod enabled off
set auto-load python-scripts off
set startup-with-shell off
handle SIGSEGV stop print nopass
handle SIGBUS stop print nopass
handle SIGABRT stop print nopass
start
python
import gdb
import hashlib
import json
import os
import struct

out = os.environ["LFORTRAN_UNIT_DIAGNOSTICS"]
events = open(os.path.join(out, "frames.jsonl"), "w", buffering=1)
regions = {}
objects = {}
history = {}
sequence = 0
current_test = "startup"

def reg(name):
    return int(gdb.parse_and_eval("$" + name))

def memory(address, size):
    return bytes(gdb.selected_inferior().read_memory(address, size))

def emit(kind, **fields):
    global sequence
    sequence += 1
    record = dict(seq=sequence, kind=kind, test=current_test,
                  thread=gdb.selected_thread().global_num, **fields)
    events.write(json.dumps(record, sort_keys=True) + "\n")
    return record

def dump_object(address):
    return memory(address, 48).hex()

def region_data(address, size):
    data = memory(address, size)
    offset = 0
    records = []
    while offset + 4 <= size:
        length = struct.unpack_from("<I", data, offset)[0]
        if length == 0:
            return dict(sha256=hashlib.sha256(data).hexdigest(),
                        sentinel=offset, records=records, hex=data.hex())
        if length == 0xffffffff or length < 4 or offset + length + 4 > size:
            return dict(invalid_offset=offset, length=length, hex=data.hex())
        cie = struct.unpack_from("<I", data, offset + 4)[0]
        records.append([offset, length, cie])
        offset += length + 4
    return dict(missing_sentinel=True, records=records, hex=data.hex())

class TestStart(gdb.Breakpoint):
    def stop(self):
        global current_test
        current_test = gdb.parse_and_eval(
            "doctest::detail::g_cs->currentTest->m_name").string()
        emit("test", live_objects=sorted(objects), live_regions=sorted(regions))
        print("FRAME_TEST", current_test, "objects", len(objects))
        for address, record in regions.items():
            now = region_data(address, record["size"])
            if now != record["data"]:
                emit("live_frame_changed", key=address, before=record["data"], after=now)
                return True
        return False

class LLVMRegister(gdb.Breakpoint):
    def stop(self):
        manager, address, size = reg("rdi"), reg("rsi"), reg("rcx")
        record = emit("llvm_register", key=address, size=size, manager=manager,
                      data=region_data(address, size))
        regions[address] = record
        if "invalid_offset" in record["data"] or "missing_sentinel" in record["data"]:
            print("INVALID_FRAME_REGISTRATION", record)
            return True
        return False

class LLVMRemove(gdb.Breakpoint):
    def stop(self):
        address, size = reg("rdi"), reg("rsi")
        original = regions.pop(address, None)
        now = region_data(address, size)
        emit("llvm_deregister", key=address, size=size, data=now,
             registration=original["seq"] if original else None,
             unchanged=original is not None and original["data"] == now)
        return False

class RegisterDone(gdb.FinishBreakpoint):
    def __init__(self, key, address, record):
        super().__init__(internal=True)
        self.key, self.address, self.record = key, address, record
    def stop(self):
        emit("gcc_registered", key=self.key, object=self.address,
             data=dump_object(self.address), registration=self.record["seq"])
        return False

class GCCRegister(gdb.Breakpoint):
    def stop(self):
        key, address = reg("rdi"), reg("rsi")
        region = regions.get(key)
        record = emit("gcc_register", key=key, object=address,
                      llvm_registration=region["seq"] if region else None)
        objects[address] = record
        history.setdefault(address, []).append(record)
        RegisterDone(key, address, record)
        return False

class RemoveDone(gdb.FinishBreakpoint):
    def __init__(self, key):
        super().__init__(internal=True)
        self.key = key
    def stop(self):
        address = reg("rax")
        original = objects.pop(address, None)
        record = emit("gcc_deregistered", key=self.key, object=address,
                      registration=original["seq"] if original else None,
                      matching_key=original is not None and original["key"] == self.key,
                      data=dump_object(address) if address else None)
        history.setdefault(address, []).append(record)
        if original is None or original["key"] != self.key:
            print("INVALID_FRAME_REMOVAL", record)
            return True
        return False

class GCCRemove(gdb.Breakpoint):
    def stop(self):
        key = reg("rdi")
        emit("gcc_deregister", key=key)
        RemoveDone(key)
        return False

class AddFDEs(gdb.Breakpoint):
    def stop(self):
        address = reg("rdi")
        record = emit("add_fdes", object=address, data=dump_object(address),
                      live=address in objects, history=history.get(address))
        if address in history and address not in objects:
            print("STALE_OBJECT_LOOKUP", record)
            return True
        return False

TestStart("doctest.h:6727", internal=True)
LLVMRegister("llvm::RTDyldMemoryManager::registerEHFrames(unsigned char*, unsigned long, unsigned long)", internal=True)
LLVMRemove("llvm::RTDyldMemoryManager::deregisterEHFramesInProcess(unsigned char*, unsigned long)", internal=True)
GCCRegister("*__register_frame_info_bases", internal=True)
GCCRemove("*__deregister_frame_info_bases", internal=True)
AddFDEs("*add_fdes", internal=True)
print("FRAME_TRACE_READY")
end
continue
python
if gdb.selected_inferior().pid:
    print("FRAME_TRACE_STOP")
    for text in ("p $_siginfo", "thread apply all bt full", "info registers",
                 "x/16i $pc", "info proc mappings", "info sharedlibrary"):
        try:
            gdb.execute(text)
        except gdb.error as error:
            print("TRACE_COMMAND_FAILED", text, error)
    events.close()
    gdb.execute("quit 97")
else:
    status = int(gdb.parse_and_eval("$_exitcode"))
    emit("exit", status=status, live_objects=sorted(objects), live_regions=sorted(regions)) if gdb.selected_thread() else None
    print("FRAME_TRACE_EXIT", status, "objects", len(objects), "regions", len(regions))
    events.close()
    gdb.execute("quit {}".format(status))
end
