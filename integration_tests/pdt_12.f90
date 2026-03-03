module pdt_12_mod
  implicit none

  integer, parameter :: default_real = kind(1.)

  type :: node_t(k)
    integer, kind :: k = default_real
    type(node_t(k)), allocatable :: next
  end type

end module

submodule(pdt_12_mod) pdt_12_sub
  implicit none
end submodule

program pdt_12
  use pdt_12_mod
  implicit none

  type(node_t(default_real)) :: head

  if (allocated(head%next)) error stop
  allocate(head%next)
  if (.not. allocated(head%next)) error stop

  print *, "ok"
end program
