! The coarray pass synthesizes declarations of the `prif` module procedures it
! calls into (Caffeine's coarray runtime) directly in the global scope, where
! they have no ASR owner. Those procedures are Fortran module procedures with an
! explicit interface, so their CHARACTER dummies (prif_stop's stop_code_char,
! prif_sync_all's errmsg) keep the DescriptorString physical type: only the
! frontend hands out HiddenLenString, and only to the dummies of a procedure it
! knows to be a separately compiled external one.
!
! Pins the physical types of the synthesized declarations after the coarray
! pass; a backend lowers them mechanically. A caller reaching the same
! procedure through `use prif` uses the descriptor ABI too, so the two agree on
! the argument list of one LLVM function (Caffeine's example/hello.F90).
program coarray_prif_char_abi_01
  implicit none
  integer :: n
  n = 1
  sync all
  print *, n
end program coarray_prif_char_abi_01
