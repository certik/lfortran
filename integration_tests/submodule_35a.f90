program submodule_35a
  use submodule_35_mod, only: operator(.det.)
  implicit none
  real(8) :: d
  d = .det.reshape([1.0d0, 2.0d0, 3.0d0, 4.0d0], [2,2])
  if (abs(d - (-2.0d0)) > 1.0d-10) error stop
  print *, "ok"
end program submodule_35a
